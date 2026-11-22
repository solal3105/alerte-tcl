// Transforme les alertes trafic TCL en éléments de carte.
//
// Le flux TCL ne donne que la ligne concernée et un texte libre. Ce texte suit des tournures
// régulières (« Les arrêts de X à Y ne sont plus desservis en direction de Z uniquement »,
// « La ligne circule uniquement de X à Y », « La ligne ne circule pas ») : on les reconnaît,
// on retrouve les arrêts cités parmi ceux de la ligne, et on découpe le tracé entre eux.
// Une alerte dont on ne reconnaît rien est rendue telle quelle, sans géométrie, pour qu'un
// humain puisse la placer.

import { versMetres, versLonLat, cumul, decouper, projeter } from "./geo.mjs";

// ── Noms d'arrêts ───────────────────────────────────────────────────────────

const ABREVIATIONS = [
  [/\bste\b/g, "sainte"],
  [/\bst\b/g, "saint"],
  [/\bhop\b/g, "hopital"],
  [/\bpl\b/g, "place"],
  [/\bav\b/g, "avenue"],
  [/\bbd\b/g, "boulevard"],
  [/\bgge\b/g, "grange"],
  [/\bgal\b/g, "general"],
  [/\bcat\b/g, "cathedrale"],
  [/\buniv\b/g, "universite"],
];

export function normaliser(s) {
  let t = s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
  for (const [re, mot] of ABREVIATIONS) t = t.replace(re, mot);
  return t.replace(/\s+/g, " ");
}

function bigrammes(s) {
  const t = ` ${s} `;
  const m = new Map();
  for (let i = 0; i < t.length - 1; i++) {
    const b = t.slice(i, i + 2);
    m.set(b, (m.get(b) || 0) + 1);
  }
  return m;
}

// Coefficient de Dice sur les paires de lettres : 1 pour deux noms identiques.
export function ressemblance(a, b) {
  if (a === b) return 1;
  const A = bigrammes(a), B = bigrammes(b);
  let commun = 0, total = 0;
  for (const [k, v] of A) { commun += Math.min(v, B.get(k) || 0); total += v; }
  for (const v of B.values()) total += v;
  return total ? (2 * commun) / total : 0;
}

const SEUIL_ARRET = 0.72;

// Les deux sens d'un arrêt forment un seul lieu quand ils sont dans la même rue : chaque point
// d'arrêt est alors au bord du tracé de l'autre sens. Quand l'aller et le retour passent par deux
// rues différentes (sens uniques, boucles), les deux points restent deux lieux. LARGEUR_RUE est
// l'ordre de grandeur d'une chaussée de boulevard, trottoirs compris.
export const LARGEUR_RUE = 30;
export function memeRue(qa, va, qb, vb) {
  return projeter(qa, vb.pts, vb.c).ecart <= LARGEUR_RUE && projeter(qb, va.pts, va.c).ecart <= LARGEUR_RUE;
}


// Un arrêt de tout le réseau plus loin que ça du tracé n'est pas retenu pour la ligne.
const ECART_MAX_ARRET = 150;
// Quand le tracé publié est déjà l'itinéraire de déviation, les arrêts fermés sont dans la rue
// abandonnée, à quelques centaines de mètres : on les cherche plus loin, sur leur nom exact.
const ECART_MAX_ARRET_TRAVAUX = 600;

function score(n, norm) {
  const r = ressemblance(n, norm);
  // Un nom cité plus court que le nom officiel (« Croix-Rousse » pour « Croix-Rousse - Place »)
  if (r < SEUIL_ARRET && n.length >= 5 && norm.startsWith(n + " ")) return 0.8;
  // … ou réduit à sa fin (« Montrochet » pour « Hôtel Région Montrochet »)
  if (r < SEUIL_ARRET && n.length >= 6 && norm.endsWith(" " + n)) return 0.75;
  return r;
}

// Cherche un arrêt cité dans le texte et renvoie son lieu, avec sa distance le long du tracé de
// ce sens. On le cherche d'abord parmi les lieux desservis par ce sens, puis parmi ceux de l'autre
// sens de la même ligne, enfin parmi tous les points d'arrêt du réseau posés sur le tracé : un
// arrêt fermé pour travaux disparaît souvent de la desserte, alors que c'est lui qu'on cherche.
// Le texte peut proposer plusieurs noms (« IUT Feyssine* / La Doua ») : on garde le meilleur.
function trouverArret(nomCite, v, reseau, ligne) {
  const variantes = nomCite.split(/\s*\/\s*/).map((x) => normaliser(x.replace(/\*/g, ""))).filter(Boolean);
  const meilleur = (candidats, placer) => {
    let best = null;
    for (const n of variantes) {
      for (const a of candidats) {
        const r = score(n, a.norm);
        if (r < SEUIL_ARRET || (best && r < best.score)) continue;
        const pose = placer(a);
        if (pose && (!best || r > best.score || pose.ecart < best.ecart)) best = { arret: pose, score: r, ecart: pose.ecart };
      }
    }
    return best?.arret || null;
  };
  const surLeTrace = (a) => {
    const q = a.q || versMetres([a.lon, a.lat]);
    const { m, ecart } = projeter(q, v.pts, v.c);
    return ecart <= (v.baseTravaux ? ECART_MAX_ARRET_TRAVAUX : ECART_MAX_ARRET) ? { ...a, q, m, ecart } : null;
  };
  return (
    meilleur(v.arrets, (a) => ({ ...a, ecart: 0 })) ||
    meilleur(Object.values(ligne?.sens || {}).filter((w) => w !== v).flatMap((w) => w.arrets), surLeTrace) ||
    meilleur(reseau.points, (a) => { const r = surLeTrace(a); return r && { ...r, seul: true, sens: v }; })
  );
}

// ── Lecture des textes ──────────────────────────────────────────────────────

// Un nom d'arrêt fait rarement plus de 60 caractères : borner la capture évite qu'elle
// déborde sur la phrase suivante.
const NOM = "(.{2,60}?)";
const NOMS = "(.{2,240}?)";
const DE = "(?:de |d'|d’|du |des )";
const A = "(?:à |a |au |aux |jusqu'à |jusqu’à )";

// Un point qui suit une abréviation de nom d'arrêt (« Hôp. Feyzin », « Entrée Princ. ») ou une
// initiale (« V. Merle ») ne termine pas la phrase.
const FIN_DE_PHRASE = "(?<!(?:^|[\\s(\\-])(?:Hôp|Hop|St|Ste|Cat|Gal|Pl|Av|Bd|Gde|Univ|Princ|[A-Z]))\\.(?: |$)|$";

const MOTIFS = [
  // Les arrêts / stations de X à Y ne sont plus desservis
  {
    type: "troncon",
    re: new RegExp(`les (?:arr[eê]ts|stations) ${DE}${NOM} ${A}${NOM} ne (?:sont|seront) (?:plus |pas )desservie?s?`, "gi"),
  },
  // Les arrêts X et Y ne sont plus desservis
  {
    type: "arrets",
    re: new RegExp(`les (?:arr[eê]ts|stations) (?!${DE}|entre )${NOMS} ne (?:sont|seront) (?:plus |pas )desservie?s?`, "gi"),
  },
  // L'arrêt X n'est plus desservi, La station X dans les deux sens de circulation n'est plus
  // desservie, La station X ne sera pas desservie en direction de Z. Le sens peut se glisser
  // entre le nom et le verbe : il est alors lu dans la tournure elle-même.
  {
    type: "arrets",
    directionDansMotif: true,
    re: new RegExp(`(?:l['’]|la |le )(?:arr[eê]t|station) ${NOM}(?: (dans les (?:deux|2) sens)(?: de circulation)?|,? (?:uniquement )?en direction (?:de |d'|d’|du )(.{2,60}?))? (?:n['’](?:est|sera) (?:plus |pas )|ne (?:sera|seront|sont) (?:plus |pas ))desservie?s?`, "gi"),
  },
  // L'arrêt X est reporté / déplacé
  {
    type: "deplace",
    re: new RegExp(`l['’]arr[eê]t ${NOM} (?:est|sera) (?:report[ée]|d[ée]plac[ée]|modifi[ée])`, "gi"),
  },
  // La ligne circule uniquement de X à Y, parfois en plusieurs morceaux : « de X à Y puis de Z
  // à W », « de X à Y et Z à W ». On capture toute l'énumération, découpée ensuite par morceaux.
  // Sans majuscules indifférentes : « le » ou « les » qui suivent la liste sont en minuscules
  // (« les lundis », « le soir »), alors qu'un nom peut en contenir (« Stade de Gerland Le LOU »).
  {
    type: "partiel",
    re: new RegExp(`circule (?:uniquement|seulement) (?:de |d'|d’|entre )(.{2,300}?)(?=${FIN_DE_PHRASE}|, (?!puis)|; | en | les | du | le | à partir| jusqu)`, "g"),
  },
];

// Morceaux d'une énumération « X à Y puis de Z à W ». Une seule paire peut aussi s'écrire
// « entre X et Y ».
export function lireMorceaux(liste) {
  const parts = liste.split(/,?\s+(?:puis|et)\s+(?:de |d'|d’|entre )?/i);
  const lus = parts.map((p) => p.match(/^(.{2,60}?) (?:à|a|au) (.{2,60})$/i));
  if (parts.length > 1 && lus.every(Boolean)) return lus.map((x) => [x[1], x[2]]);
  const un = liste.match(/^(.{2,60}?) (?:à|a|au|et) (.{2,60})$/i);
  return un ? [[un[1], un[2]]] : [];
}

const RE_TOUTE_LIGNE = /(?:ne circule (?:pas|plus)|est interrompue?|circulation (?:est )?interrompue|trafic (?:est )?interrompu)/i;
// La direction se termine de préférence sur « uniquement », parce que les noms de terminus
// contiennent souvent des points (« Bellecour A. Poncet », « Hôp. Sud »).
const RE_DIRECTION_APRES = /^\s*,?\s*(?:(?:uniquement |seulement )?en direction (?:de |d'|d’|du )(.{2,60}?) (?:uniquement|seulement)|(dans les deux sens|dans les 2 sens))/i;
const RE_DIRECTION_APRES_COURTE = /^\s*,?\s*(?:uniquement |seulement )?en direction (?:de |d'|d’|du )(.{2,60}?)(?:[,;]|\. |\.?$)/i;
// « En direction de Parc Technologique,Gare de Vénissieux, les arrêts… » : la direction précède
// la tournure et se termine par une virgule. Elle peut contenir des points et des virgules.
const RE_DIRECTION_AVANT = /^en direction (?:de |d'|d’|du |des )?(.{2,120}?)\s*[,:]\s*$/i;
const RE_HORAIRES =
  /(à partir de \d{1,2}\s?h|en soirée|en journée|certains soirs|les (?:lundis|mardis|mercredis|jeudis|vendredis|samedis|dimanches)|du lundi au|de \d{1,2}\s?h\d*\s?à \d{1,2}\s?h|entre \d{1,2}\s?h\d* et \d{1,2}\s?h|le (?:matin|soir)|week-end)/i;

function nettoyer(texte) {
  return texte
    .replace(/\s+/g, " ")
    .replace(/\s+([.,;])/g, "$1")
    // « Cordeliers.L'arrêt » : un point collé à la phrase suivante
    .replace(/([a-zà-ÿ]{2}|\))\.(?=[A-ZÀ-Ý])/g, "$1. ")
    // « … à IUT Feyssine La reprise de la circulation est estimée » : le point oublié avant
    // une phrase de service, sans lequel le nom de l'arrêt avalerait la phrase suivante.
    .replace(/([^\s.!?;:,])\s+(?=(?:La reprise|Une manifestation|Nous (?:vous|mettons|invitons)|Des bus relais|Des travaux|Plus d['’]informations|Pour vos d[ée]placements)\b)/g, "$1. ")
    .trim();
}

function lireDirection(texte, debut, fin) {
  const suite = texte.slice(fin, fin + 140);
  const apres = suite.match(RE_DIRECTION_APRES);
  if (apres) return apres[2] ? null : apres[1];
  const courte = suite.match(RE_DIRECTION_APRES_COURTE);
  if (courte) return courte[1];
  const precede = texte.slice(Math.max(0, debut - 160), debut);
  const k = precede.toLowerCase().lastIndexOf("en direction");
  const avant = k >= 0 ? precede.slice(k).match(RE_DIRECTION_AVANT) : null;
  return avant ? avant[1] : null;
}

export function lireTexte(message) {
  const texte = nettoyer(message || "");
  const effets = [];
  const occupe = [];
  for (const { type, re, directionDansMotif } of MOTIFS) {
    re.lastIndex = 0;
    for (const m of texte.matchAll(re)) {
      const debut = m.index, fin = m.index + m[0].length;
      if (occupe.some(([a, b]) => debut < b && fin > a)) continue;
      occupe.push([debut, fin]);
      const direction = directionDansMotif && m[2] ? null : directionDansMotif && m[3] ? m[3] : lireDirection(texte, debut, fin);
      if (type === "troncon") effets.push({ type, de: m[1], a: m[2], direction });
      else if (type === "partiel") {
        const morceaux = lireMorceaux(m[1]);
        if (morceaux.length) effets.push({ type, morceaux, de: morceaux[0][0], a: morceaux[0][1], direction });
      } else if (type === "deplace") effets.push({ type, de: m[1], direction });
      else {
        for (const nom of m[1].split(/\s*(?:,| et )\s*/)) if (nom) effets.push({ type, de: nom, direction });
      }
    }
  }
  // « La ligne circule uniquement de X à Y » décrit tout ce qui roule encore : on la place avant
  // les phrases qui listent les arrêts fermés, qui ne servent plus que pour un sens où elle ne se
  // place pas.
  effets.sort((x, y) => (y.type === "partiel") - (x.type === "partiel"));
  if (!effets.some((e) => e.type === "partiel") && RE_TOUTE_LIGNE.test(texte)) {
    // « ne circule pas » sans autre précision : toute la ligne, sauf si le texte parle
    // d'un tronçon non desservi, auquel cas ce tronçon suffit.
    if (!effets.some((e) => e.type === "troncon")) effets.push({ type: "ligne" });
  }
  return { texte, effets, horairesPartiels: RE_HORAIRES.test(texte) };
}

// ── Réseau ──────────────────────────────────────────────────────────────────

export function preparerReseau(brut) {
  const lieux = brut.lieux.map(([nom, lon, lat], lieu) => ({ lieu, nom, lon, lat, norm: normaliser(nom) }));
  const points = brut.points.map(([nom, lon, lat], i) => ({ lieu: `p${i}`, nom, lon, lat, norm: normaliser(nom), q: versMetres([lon, lat]) }));
  const lignes = {};
  for (const [code, l] of Object.entries(brut.lignes)) {
    const sens = {};
    for (const [s, v] of Object.entries(l.sens)) {
      const pts = v.trace.map(versMetres);
      sens[s] = {
        ...v,
        sens: s,
        pts,
        c: cumul(pts),
        arrets: v.arrets.map(([lieu, m]) => ({ ...lieux[lieu], m })),
        destNorm: normaliser(v.destination || ""),
      };
    }
    lignes[code] = { ...l, sens };
  }
  return { genere: brut.genere, lignes, lieux, points };
}

// Quel sens correspond à « en direction de Z » ? On compare Z au terminus et au dernier arrêt de
// chaque sens ; Z peut nommer plusieurs terminus (« Gare de Vénissieux,Porte des Alpes »). Si Z
// n'est aucun terminus (un terminus partiel comme « St-Genis Lycée Descartes »), on cherche le
// lieu Z sur le réseau et on garde le sens qui s'en rapproche après l'arrêt cité.
function sensVers(ligne, direction, reseau, nomCite) {
  const tous = Object.keys(ligne.sens);
  if (!direction) return tous;
  const parties = direction.split(/\s*(?:,|\/| et | ou )\s*/).map(normaliser).filter(Boolean);
  let best = null, meilleur = 0;
  for (const s of tous) {
    const v = ligne.sens[s];
    const fin = v.arrets.at(-1)?.norm || "";
    for (const n of parties) {
      const r = Math.max(ressemblance(n, v.destNorm), ressemblance(n, fin), v.destNorm.startsWith(n) ? 0.9 : 0);
      if (r > meilleur) { meilleur = r; best = s; }
    }
  }
  if (meilleur >= 0.5) return [best];

  let z = null, rz = 0;
  for (const n of parties) {
    for (const lieu of reseau.lieux) {
      const r = score(n, lieu.norm);
      if (r >= SEUIL_ARRET && r > rz) { rz = r; z = lieu; }
    }
  }
  if (!z) return tous;
  const qz = versMetres([z.lon, z.lat]);
  const devant = tous.filter((s) => {
    const v = ligne.sens[s];
    const x = nomCite && trouverArret(nomCite, v, reseau, ligne);
    const { m, ecart } = projeter(qz, v.pts, v.c);
    return x && ecart <= ECART_MAX_DIRECTION && m > x.m;
  });
  // Sur une ligne en boucle, les deux sens peuvent s'en rapprocher : on ne tranche pas.
  return devant.length === 1 ? devant : tous;
}

// Un terminus partiel est souvent à l'écart du tracé principal (le lycée Descartes est à 600 m
// de celui de la 117) ; sa projection suffit à dire de quel côté de l'arrêt cité il se trouve.
const ECART_MAX_DIRECTION = 1500;

const enLonLat = (pts) => pts.map(versLonLat).map(([x, y]) => [Math.round(x * 1e5) / 1e5, Math.round(y * 1e5) / 1e5]);

// ── Alertes ─────────────────────────────────────────────────────────────────

const MODES = { "Métro": "metro", "Funiculaire": "metro", "Tramway": "tram", "Bus": "bus" };

// Heure de Paris au format des alertes (« 2026-11-12 00:20:04 »).
export function maintenantParis(date = new Date()) {
  const f = new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Europe/Paris",
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit",
  });
  return f.format(date).replace("T", " ");
}

// ── Dates ───────────────────────────────────────────────────────────────────
//
// Une même perturbation publiée en double (une entrée par objet concerné) n'est lue qu'une fois. Ses
// fenêtres disent quand elle s'applique ; les applications décident seules si c'est maintenant ou plus
// tard, si bien que le fichier publié reste juste entre deux lectures.

const RE_REPRISE_ANNONCEE = /circulation reprend|reprend progressivement|retour (?:progressif )?(?:à la )?normale|trafic (?:est )?r[ée]tabli/i;

// Identité d'une alerte : la même que AlertIdentity dans le module partagé des applications
// (ligne, titre, début et empreinte FNV-1a du message), pour qu'une coupure se rattache à l'alerte
// que l'application affiche. Le champ « n » n'est que le rang de l'alerte dans la réponse.
export function identiteAlerte(a) {
  const net = (t) => (t ?? "").trim();
  let h = 2166136261;
  for (const c of net(a.message)) for (let k = 0; k < c.length; k++) h = Math.imul((h ^ c.charCodeAt(k)) >>> 0, 16777619) >>> 0;
  return `${net(a.ligne_com)}|${net(a.ligne_cli)}|${net(a.titre)}|${net(a.debut)}|${h.toString(16)}`;
}

// TCL publie souvent une seule alerte pour plusieurs semaines et ne dit que dans son titre ou son
// texte qu'elle ne s'applique que certains jours, à partir d'une certaine heure : « du 5 octobre au
// 24 novembre, les lundis et mardis à partir de 21h20 », « les 25, 26, 27 octobre et les 1, 2, 3
// novembre à partir de 20h30 ». On en tire les fenêtres où elle s'applique vraiment, une par jour de
// service, prises dans la période publiée. Un jour de service court jusqu'à la fin du service, vers
// 2 h 30 le lendemain : une heure avant 3 h appartient au jour précédent. Sans précision d'heure, une
// fenêtre commence et finit aux heures de la période publiée (en général le début et la fin du
// service). Des dates citées qui ne tombent pas dans la période publiée parlent d'autre chose (une
// autre phase de travaux) et sont ignorées.

const MOIS = { janvier: 1, fevrier: 2, mars: 3, avril: 4, mai: 5, juin: 6, juillet: 7, aout: 8, septembre: 9, octobre: 10, novembre: 11, decembre: 12 };
const JOURS = { dimanche: 0, lundi: 1, mardi: 2, mercredi: 3, jeudi: 4, vendredi: 5, samedi: 6 };
const NOM_JOUR = `(?:${Object.keys(JOURS).join("|")})s?`;
const NUMERO = "\\d{1,2}(?:er)?";
// « les 1, 2, 3 et 11 novembre », « le mercredi 11 novembre 2026 », « sauf 7 et 8 décembre ».
const RE_DATES = new RegExp(`\\b(les?|sauf(?: les?)?)\\s+(?:${NOM_JOUR}\\s+)?((?:${NUMERO}\\s*(?:,|et)\\s*)*${NUMERO})\\s+(${Object.keys(MOIS).join("|")})(?:\\s+(\\d{4}))?`, "g");
// « Depuis le 1er septembre » ou « à compter du » donnent le début de la période, pas une date isolée.
const RE_AVANT_DEBUT = /\b(?:depuis|partir|compter|des)\s*$/;
// « les lundis et mardis », mais pas « les dimanches 1er et 29 novembre », lu comme des dates.
const RE_JOURS = new RegExp(`\\bles\\s+(${NOM_JOUR}(?:\\s*(?:,|et)\\s*${NOM_JOUR})*)\\b(?!\\s*\\d)`, "g");
const RE_JOURS_DE_A = new RegExp(`\\bdu (${Object.keys(JOURS).join("|")}) au (${Object.keys(JOURS).join("|")})\\b`);
const HEURE = "(\\d{1,2})\\s?h\\s?(\\d{2})?";
const RE_HEURES_ENTRE = new RegExp(`\\b(?:de|entre)\\s+${HEURE}\\s+(?:a|et)\\s+${HEURE}`);
const RE_HEURE_DEBUT = new RegExp(`\\ba partir de\\s+${HEURE}`);
// Un moment de la journée sans heure : la fenêtre reste approximative.
const RE_MOMENT_SANS_HEURE = /en soiree|en journee|le (?:matin|soir)|certains soirs/;

const sansAccents = (s) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
const versDate = (s) => new Date(s.replace(" ", "T") + "Z");
const ajouterJours = (j, n) => { const d = versDate(`${j} 00:00:00`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
const jourDeService = (s) => new Date(versDate(s) - 3 * 3600_000).toISOString().slice(0, 10);
const heureLue = (h, m) => `${h.padStart(2, "0")}:${m || "00"}:00`;

export function lireCalendrier(a) {
  const publiee = [{ debut: a.debut, fin: a.fin || null }];
  if (!a.debut || !a.fin) return { fenetres: publiee, precis: false, restreint: false };
  // Les phrases sur les bus relais ou sur des départs précis ont leurs propres heures (« un départ
  // toutes les 12 minutes de 4h28 à 12h05 », « sur le trajet de 11h20 les mercredis ») : on les écarte.
  const t = `${a.titre || ""}. ${a.message || ""}`
    .split(/(?<=[.!?:;·•])\s*|\s+-\s+|(?<=[a-zà-ÿ0-9])(?=[A-ZÀ-Ý][a-zà-ÿ])/)
    .map((p) => sansAccents(p).replace(/\s+/g, " "))
    .filter((p) => !/bus relais|navette|depart|trajet/.test(p))
    .join(" ");
  const premier = jourDeService(a.debut), dernier = jourDeService(a.fin);
  const annees = [...new Set([premier.slice(0, 4), dernier.slice(0, 4)])];

  const dates = new Set(), sauf = new Set();
  let citees = 0;
  for (const m of t.matchAll(RE_DATES)) {
    if (RE_AVANT_DEBUT.test(t.slice(Math.max(0, m.index - 12), m.index))) continue;
    for (const n of m[2].split(/\s*(?:,|et)\s*/)) {
      const mmjj = `${String(MOIS[m[3]]).padStart(2, "0")}-${String(parseInt(n, 10)).padStart(2, "0")}`;
      const j = (m[4] ? [m[4]] : annees).map((y) => `${y}-${mmjj}`).find((j) => j >= premier && j <= dernier);
      if (!m[1].startsWith("sauf")) citees++;
      if (j) (m[1].startsWith("sauf") ? sauf : dates).add(j);
    }
  }
  const jours = new Set();
  for (const m of t.matchAll(RE_JOURS)) for (const n of m[1].split(/\s*(?:,|et)\s*/)) jours.add(JOURS[n.replace(/s$/, "")]);
  const deA = t.match(RE_JOURS_DE_A);
  if (deA) for (let j = JOURS[deA[1]]; ; j = (j + 1) % 7) { jours.add(j); if (j === JOURS[deA[2]]) break; }
  const entre = t.match(RE_HEURES_ENTRE), aPartir = t.match(RE_HEURE_DEBUT);
  const heureDebut = entre ? heureLue(entre[1], entre[2]) : aPartir ? heureLue(aPartir[1], aPartir[2]) : null;
  const heureFin = entre ? heureLue(entre[3], entre[4]) : null;
  // TCL cite des jours dont aucun ne tombe dans la période publiée (la T3 « le 9, 10, 25 et 27
  // novembre » publiée pour le 23) : la période fait foi, et l'application signale l'écart.
  const contradiction = citees > 0 && !dates.size;
  if (!dates.size && !jours.size && !sauf.size && !heureDebut) return { fenetres: publiee, precis: false, restreint: false, contradiction };

  const debutJour = heureDebut ?? a.debut.slice(11, 19);
  const finJour = heureFin ?? a.fin.slice(11, 19);
  const fenetres = [];
  for (let j = premier; j <= dernier; j = ajouterJours(j, 1)) {
    if (dates.size ? !dates.has(j) : jours.size && !jours.has(versDate(`${j} 00:00:00`).getUTCDay())) continue;
    if (sauf.has(j)) continue;
    const debut = `${j} ${debutJour}`;
    const fin = `${finJour < "03:00:00" || finJour <= debutJour ? ajouterJours(j, 1) : j} ${finJour}`;
    const w = { debut: debut > a.debut ? debut : a.debut, fin: fin < a.fin ? fin : a.fin };
    if (w.debut < w.fin) fenetres.push(w);
  }
  // Rien ne tombe dans la période publiée : le texte parle d'autre chose, la période fait foi.
  if (!fenetres.length) return { fenetres: publiee, precis: false, restreint: false, contradiction };
  return { fenetres, precis: Boolean(heureDebut) || !RE_MOMENT_SANS_HEURE.test(t), restreint: true, contradiction };
}

// Arrêts du parcours encore desservis. Un arrêt fermé l'est sous tous ses lieux de même nom :
// un terminus en boucle a souvent deux points d'arrêt du même nom, à l'arrivée et au départ.
function encoreDesservis(v, fermes) {
  const noms = new Set(fermes.map((f) => f.norm));
  return v.arrets.filter((ar) => !noms.has(ar.norm));
}

// Le véhicule quitte son parcours au dernier arrêt encore desservi avant les arrêts fermés et le
// retrouve au premier arrêt desservi après eux : c'est ce tronçon qu'on trace. S'il n'y a plus
// d'arrêt desservi d'un côté, la ligne ne va plus jusqu'à son terminus : c'est une limitation.
function bloc(v, fermes) {
  const m1 = Math.min(...fermes.map((f) => f.m)), m2 = Math.max(...fermes.map((f) => f.m));
  const desservis = encoreDesservis(v, fermes);
  const avant = desservis.filter((ar) => ar.m < m1).at(-1);
  const apres = desservis.find((ar) => ar.m > m2);
  return { avant, apres, d: avant ? avant.m : 0, f: apres ? apres.m : v.c.at(-1) };
}

// Des arrêts fermés d'une même alerte forment un seul bloc tant qu'aucun arrêt desservi ne les
// sépare sur le parcours.
function blocsConsecutifs(v, fermes) {
  const uniques = [...new Map(fermes.map((f) => [f.lieu, f])).values()].sort((a, b) => a.m - b.m);
  const desservis = encoreDesservis(v, uniques);
  const blocs = [];
  for (const f of uniques) {
    const dernier = blocs.at(-1);
    const separe = dernier && desservis.some((ar) => ar.m > dernier.at(-1).m && ar.m < f.m);
    if (!dernier || separe) blocs.push([f]); else dernier.push(f);
  }
  return blocs;
}

// Point situé à la distance m le long du tracé.
function pointA(v, m) {
  const mm = Math.max(0, Math.min(v.c.at(-1) - 1, m));
  return decouper(v.pts, v.c, mm, mm + 1)?.[0] || v.pts[0];
}

// Arrêts desservis qui encadrent des arrêts fermés absents du tracé : la paire d'arrêts
// consécutifs dont le segment passe au plus près de tous les arrêts fermés. Avec un terminus
// déplacé, les arrêts fermés peuvent aussi être au-delà du premier ou du dernier arrêt desservi.
function distanceAuSegment(p, a, b) {
  const dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy;
  const t = l2 ? Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2)) : 0;
  return Math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy);
}
// Des arrêts fermés trouvés loin du tracé : ce tracé de travaux contourne déjà leur rue.
const horsTrace = (v, fermes) => v.baseTravaux && fermes.some((f) => (f.ecart ?? 0) > ECART_MAX_ARRET);

function encadrer(v, fermes, terminus) {
  const q = (x) => x.q || versMetres([x.lon, x.lat]);
  const desservis = encoreDesservis(v, fermes);
  let best = { avant: null, apres: null, cout: Infinity };
  const essayer = (avant, apres, aEgalite) => {
    const cout = Math.max(...fermes.map((f) => avant && apres ? distanceAuSegment(q(f), q(avant), q(apres)) : Math.hypot(...[0, 1].map((k) => q(f)[k] - q(avant || apres)[k]))));
    if (cout < best.cout || (aEgalite && cout <= best.cout)) best = { avant, apres, cout };
  };
  for (let k = 1; k < desservis.length; k++) essayer(desservis[k - 1], desservis[k]);
  // Une alerte « terminus » : à distance égale, des arrêts fermés au-delà du dernier arrêt
  // desservi sont un terminus déplacé, pas une déviation.
  if (terminus && desservis.length) { essayer(null, desservis[0], true); essayer(desservis.at(-1), null, true); }
  return best;
}

// Arrêts fermés dans l'ordre du parcours : projetés sur le segment qui va de l'arrêt d'avant à
// celui d'après, ou, faute d'arrêt d'après, de proche en proche depuis l'arrêt d'avant.
function ordonner(fermes, depuis, vers) {
  const q = (x) => x.q || versMetres([x.lon, x.lat]);
  const uniques = [...new Map(fermes.map((f) => [f.lieu, f])).values()];
  const a = q(depuis);
  if (vers) {
    const b = q(vers), dx = b[0] - a[0], dy = b[1] - a[1];
    return uniques.sort((x, y) => ((q(x)[0] - a[0]) * dx + (q(x)[1] - a[1]) * dy) - ((q(y)[0] - a[0]) * dx + (q(y)[1] - a[1]) * dy));
  }
  return uniques.sort((x, y) => Math.hypot(q(x)[0] - a[0], q(x)[1] - a[1]) - Math.hypot(q(y)[0] - a[0], q(y)[1] - a[1]));
}

// Deux sens touchés de la même façon et qui passent dans la même rue ne font qu'un trait : chaque
// point de l'un, pris tous les 40 m, est à moins d'une largeur de rue de l'autre, et inversement.
const PAS_COMPARAISON = 40;
function echantillon(pts, c) {
  const out = [];
  for (let m = 0; m < c.at(-1); m += PAS_COMPARAISON) out.push(pointA({ pts, c }, m));
  out.push(pts.at(-1));
  return out;
}
function memeTrace(f, g) {
  const a = f.geometry.coordinates.map(versMetres), b = g.geometry.coordinates.map(versMetres);
  const ca = cumul(a), cb = cumul(b);
  return echantillon(a, ca).every((p) => projeter(p, b, cb).ecart <= LARGEUR_RUE) &&
    echantillon(b, cb).every((p) => projeter(p, a, ca).ecart <= LARGEUR_RUE);
}
function fusionnerSens(features) {
  const groupes = new Map();
  for (const f of features) {
    if (f.geometry.type !== "LineString") continue;
    const p = f.properties;
    const k = `${p.id}|${p.effet}`;
    if (!groupes.has(k)) groupes.set(k, []);
    groupes.get(k).push(f);
  }
  const absorbes = new Set();
  for (const liste of groupes.values()) {
    for (const f of liste) {
      if (absorbes.has(f) || f.properties.deuxSens) continue;
      const jumeau = liste.find((g) => g !== f && !absorbes.has(g) && !g.properties.deuxSens && g.properties.sens !== f.properties.sens && memeTrace(f, g));
      if (jumeau) {
        f.properties = { ...f.properties, deuxSens: true };
        absorbes.add(jumeau);
      }
    }
  }
  return features.filter((f) => !absorbes.has(f));
}

export function analyser(alertes, reseau, maintenant = maintenantParis()) {
  const features = [];
  const nonPlacees = [];
  const perturbations = [];
  let horsReseau = 0;

  // Chaque alerte est lue avec toutes les fenêtres où elle s'applique vraiment et qui ne sont pas
  // finies : l'application décide elle-même, à chaque instant, si l'une d'elles est en cours. TCL
  // publie parfois la même alerte plusieurs fois (une par objet concerné) : on n'en garde qu'une.
  const vues = new Set();
  const lues = [];
  for (const a of alertes) {
    const k = identiteAlerte(a);
    if (vues.has(k)) continue;
    vues.add(k);
    const { fenetres, precis, restreint, contradiction } = lireCalendrier(a);
    const restantes = fenetres.filter((w) => !w.fin || w.fin >= maintenant);
    if (!restantes.length) continue;
    const lu = lireTexte(a.message);
    // Quand le calendrier lu dans le texte donne les heures, les fenêtres sont exactes.
    const horairesPartiels = restreint ? !precis : lu.horairesPartiels;
    lues.push({ a, fenetres: restantes, ligne: reseau.lignes[a.ligne_com] || reseau.lignes[a.ligne_cli], ...lu, horairesPartiels, datesContradictoires: contradiction });
  }

  for (const { a, fenetres, ligne, texte, effets, horairesPartiels, datesContradictoires } of lues) {
    const fiche = {
      id: identiteAlerte(a),
      ligne: a.ligne_cli || a.ligne_com,
      code: ligne ? (reseau.lignes[a.ligne_com] ? a.ligne_com : a.ligne_cli) : null,
      // TCL range les trambus avec le tramway ; le Grand Lyon les publie comme des bus.
      mode: ligne?.mode === "trambus" ? "trambus" : MODES[a.mode] || (ligne?.mode ?? "autre"),
      couleur: ligne?.couleur || "#777777",
      titre: a.titre,
      message: texte,
      // Période publiée par TCL, et fenêtres où l'alerte s'applique vraiment (une par soirée pour
      // des travaux du soir), dans l'ordre.
      debut: a.debut,
      fin: a.fin,
      fenetres: fenetres.map(({ debut, fin }) => ({ debut, fin })),
      horairesPartiels,
      datesContradictoires,
      gravite: a.typeseverite,
      destinations: ligne ? Object.fromEntries(Object.entries(ligne.sens).map(([s, v]) => [s, v.destination])) : {},
      effets: [],
    };

    if (ligne) {
      // Bus et trambus roulent dans les rues : coupés, ils sont déviés.
      const routier = fiche.mode === "bus" || fiche.mode === "trambus";
      // Les noms que l'alerte donne comme terminus (« en direction de Jean Macé »).
      const terminusCites = effets.flatMap((e) => (e.direction ? e.direction.split(/\s*(?:,|\/| et | ou )\s*/).map(normaliser).filter(Boolean) : []));
      // Un arrêt n'a qu'une marque par alerte, posée sur son lieu. Deux points d'arrêt trouvés
      // hors desserte (un par sens) ne font qu'une marque s'ils sont dans la même rue.
      const marques = [];
      const marquer = (props, effet, lieu, dansTroncon = false) => {
        const deja = marques.find((k) => k.effet === effet && (k.lieu === lieu.lieu ||
          (k.seul && lieu.seul && k.norm === lieu.norm && memeRue(k.q, k.v, lieu.q, lieu.sens))));
        if (deja) {
          if (deja.lieu !== lieu.lieu) {
            const [x, y] = versLonLat([(deja.q[0] + lieu.q[0]) / 2, (deja.q[1] + lieu.q[1]) / 2]);
            deja.feature.geometry.coordinates = [Math.round(x * 1e5) / 1e5, Math.round(y * 1e5) / 1e5];
          }
          return;
        }
        const feature = { type: "Feature", properties: { ...props, effet, nom: lieu.nom, dansTroncon }, geometry: { type: "Point", coordinates: [lieu.lon, lieu.lat] } };
        features.push(feature);
        marques.push({ effet, lieu: lieu.lieu, seul: lieu.seul, norm: lieu.norm, q: lieu.q, v: lieu.sens, feature });
      };
      const trait = (props, effet, v, m1, m2) => {
        const morceau = decouper(v.pts, v.c, m1, m2);
        if (morceau) features.push({ type: "Feature", properties: { ...props, effet }, geometry: { type: "LineString", coordinates: enLonLat(morceau) } });
      };
      // Arrêts fermés consécutifs : déviation entre les arrêts desservis qui les encadrent, ou
      // limitation quand ils touchent un terminus.
      const terminus = /terminus/i.test(`${a.titre} ${texte}`);
      // Un tracé de travaux de ce sens qui commence le jour de l'alerte (à trois jours près) :
      // l'alerte et les horaires de la semaine décrivent la même déviation.
      const memeDate = (v) => (v.debutsTravaux || []).some((d) => a.debut && Math.abs(new Date(d) - new Date(a.debut.slice(0, 10))) <= 3 * 86400_000);
      // Les arrêts encore desservis qui encadrent une déviation, une coupure ou une limitation :
      // c'est là que le voyageur descend ou remonte.
      const borner = (props, ...bornes) => { for (const b of bornes) if (b) marquer(props, "arret-borne", b); };
      // Un bus dévié ne passe plus à ses arrêts fermés, sauf si la déviation est déjà dans les
      // horaires de la semaine (tracé de travaux du même jour, ou arrêts sortis de la desserte) :
      // ils ne sont alors plus des arrêts de la ligne. Le détour lui-même n'est pas dessiné.
      const devier = (v, fermes, effet, marquerFermes) => {
        if (memeDate(v) || fermes.every((f) => !v.arrets.some((ar) => ar.norm === f.norm))) effet.integree = true;
        else marquerFermes();
      };
      const fermer = (props, v, fermes, effetTroncon) => {
        // Les arrêts fermés d'une déviation de bus ne sont marqués qu'une fois la déviation tracée :
        // si elle est déjà intégrée aux horaires, ils ne sont plus des arrêts de la ligne.
        const marquerFermes = () => { for (const ar of fermes) marquer(props, "arret-non-desservi", ar, true); };
        // Ligne dont TCL ne publie plus que l'itinéraire de travaux, et dont les arrêts fermés ne
        // sont pas sur ce tracé : le tracé est déjà la déviation. On encadre les arrêts fermés par
        // les arrêts desservis entre lesquels ils se trouvent.
        if (horsTrace(v, fermes) && routier) {
          const { avant, apres } = encadrer(v, fermes, terminus);
          if (!avant && !apres) { marquerFermes(); return; }
          borner(props, avant, apres);
          let effet;
          if (avant && apres) {
            const tri = ordonner(fermes, avant, apres);
            effet = { effet: "deviation", sens: v.sens, de: tri[0].nom, a: tri.length > 1 ? tri.at(-1).nom : null, entre: [avant.nom, apres.nom] };
          } else {
            const tri = ordonner(fermes, avant || apres, null);
            effet = { effet: "limitation", sens: v.sens, ...(apres ? { depart: apres.nom, origine: tri.at(-1).nom } : { terminus: avant.nom }) };
          }
          fiche.effets.push(effet);
          devier(v, fermes, effet, marquerFermes);
          return;
        }
        let { avant, apres, d, f } = bloc(v, fermes);
        // Un arrêt fermé que l'alerte nomme comme terminus (« en direction de Jean Macé ») : ce
        // jour-là, la ligne s'arrête à cet arrêt, même si le tracé de référence va plus loin (la 36
        // ne va à Part-Dieu qu'en soirée). C'est une limitation, et la partie du tracé au-delà de
        // ce terminus n'est de toute façon pas parcourue. Quand l'alerte cite aussi le terminus de
        // référence de ce côté (« en direction de Parc Technologique, Gare de Vénissieux »), l'arrêt
        // fermé n'est qu'un terminus partiel parmi d'autres et la ligne continue au-delà.
        let auLieuDe = null;
        if (avant && apres && terminusCites.length) {
          const tri = fermes.slice().sort((x, y) => x.m - y.m);
          const estCite = (norm) => !!norm && terminusCites.some((n) => score(n, norm) >= SEUIL_ARRET);
          const estTerminus = (x) => estCite(x.norm);
          const finCitee = estCite(v.destNorm) || estCite(v.arrets.at(-1)?.norm);
          const debutCite = estCite(normaliser(v.origine || "")) || estCite(v.arrets[0]?.norm);
          if (estTerminus(tri.at(-1)) && !finCitee) {
            ({ m: f, nom: auLieuDe } = tri.at(-1));
            apres = null;
          } else if (estTerminus(tri[0]) && !debutCite) {
            ({ m: d, nom: auLieuDe } = tri[0]);
            avant = null;
          }
        }
        borner(props, avant, apres);
        const differe = avant && apres && effetTroncon === "deviation";
        const limitationIntegree = (!avant || !apres) && routier && memeDate(v);
        if (!differe && !limitationIntegree) marquerFermes();
        if (!avant && !apres) {
          trait(props, "interruption", v, 0, v.c.at(-1));
          fiche.effets.push({ effet: "interruption", sens: v.sens, toute: true });
        } else if (!avant || !apres) {
          // Limitation de bus déjà intégrée aux horaires : le tracé de la semaine s'arrête déjà là.
          const integree = routier && memeDate(v);
          if (!integree) trait(props, "interruption", v, d, f);
          fiche.effets.push({ effet: "limitation", sens: v.sens, ...(apres ? { depart: apres.nom, origine: auLieuDe ?? v.arrets[0]?.nom } : { terminus: avant.nom, ...(auLieuDe ? { auLieuDe } : {}) }), ...(integree ? { integree } : {}) });
        } else {
          const tri = fermes.slice().sort((x, y) => x.m - y.m);
          const effet = { effet: effetTroncon, sens: v.sens, de: tri[0].nom, a: tri.length > 1 ? tri.at(-1).nom : null, entre: [avant.nom, apres.nom] };
          fiche.effets.push(effet);
          if (differe) devier(v, fermes, effet, marquerFermes);
          else trait(props, effetTroncon, v, d, f);
        }
      };
      // Une alerte de bus « déviée » ou « terminus » qui liste des arrêts non desservis décrit
      // une déviation ou une limitation : on regroupe ces arrêts par sens avant de la tracer.
      const devie = routier && /d[ée]vi[ée]|terminus/i.test(`${a.titre} ${texte}`);
      const fermesParSens = new Map();
      // Sens où « circule uniquement » s'est placé, et coupure plutôt que déviation : une ligne qui
      // circule en deux parties ne contourne pas le trou entre elles.
      const partielPlace = new Set();
      const enParties = effets.some((e) => e.type === "partiel");

      for (const e of effets) {
        for (const s of sensVers(ligne, e.direction, reseau, e.de)) {
          const v = ligne.sens[s];
          const props = { id: fiche.id, ligne: fiche.ligne, mode: fiche.mode, couleur: fiche.couleur, sens: s, destination: v.destination, horairesPartiels };
          if (e.type === "ligne") {
            trait(props, "interruption", v, 0, v.c.at(-1));
            for (const ar of v.arrets) marquer(props, "arret-non-desservi", ar, true);
            fiche.effets.push({ effet: "interruption", sens: s, toute: true });
            continue;
          }
          const x = trouverArret(e.de, v, reseau, ligne);
          const y = e.a ? trouverArret(e.a, v, reseau, ligne) : null;
          if (!x || (e.a && !y)) continue;

          if (e.type === "troncon") {
            if (partielPlace.has(s)) continue;
            const [m1, m2] = [Math.min(x.m, y.m), Math.max(x.m, y.m)];
            // Sur un tracé de travaux, les arrêts situés entre X et Y sur le tracé sont ceux de la
            // déviation, desservis : seuls X et Y sont fermés (et ceux entre eux, que le texte ne cite pas).
            const fermes = horsTrace(v, [x, y]) ? [...new Map([x, y].map((f) => [f.lieu, f])).values()] : [x, y, ...v.arrets.filter((ar) => ar.m > m1 && ar.m < m2)];
            fermer(props, v, fermes, routier && !enParties ? "deviation" : "interruption");
          } else if (e.type === "partiel") {
            // La ligne ne roule que sur ces morceaux, dans l'ordre du parcours : tout le reste est coupé.
            const bouts = e.morceaux.map(([de, vers]) => [trouverArret(de, v, reseau, ligne), trouverArret(vers, v, reseau, ligne)]);
            if (bouts.some(([p, q]) => !p || !q)) continue;
            const roule = bouts.map(([p, q]) => (p.m <= q.m ? [p, q] : [q, p])).sort((u, w) => u[0].m - w[0].m);
            const premier = v.arrets[0]?.m ?? 0, dernier = v.arrets.at(-1)?.m ?? v.c.at(-1);
            const coupes = [];
            let curseur = 0;
            for (const [p, q] of roule) {
              if (p.m > Math.max(curseur, premier) + 1) coupes.push([curseur, p.m]);
              curseur = Math.max(curseur, q.m);
            }
            if (curseur < dernier - 1) coupes.push([curseur, v.c.at(-1)]);
            // Déjà intégré aux horaires de la semaine : rien à barrer, le tracé publié s'arrête là.
            const integree = routier && memeDate(v);
            for (const [m1, m2] of coupes) {
              if (!integree) trait(props, "interruption", v, m1, m2);
            }
            if (!integree) {
              for (const ar of v.arrets.filter((ar) => !roule.some(([p, q]) => ar.m >= p.m - 1 && ar.m <= q.m + 1))) marquer(props, "arret-non-desservi", ar, true);
            }
            // Les bouts de chaque morceau, sauf les terminus habituels, sont des terminus provisoires.
            for (const [p, q] of roule) {
              if (p.m > premier + 1) borner(props, p);
              if (q.m < dernier - 1) borner(props, q);
            }
            partielPlace.add(s);
            fiche.effets.push({ effet: "partiel", sens: s, de: roule[0][0].nom, a: roule[0][1].nom, morceaux: roule.map(([p, q]) => [p.nom, q.nom]), ...(integree ? { integree } : {}) });
          } else if (e.type === "arrets" && devie) {
            if (!fermesParSens.has(s)) fermesParSens.set(s, { props, v, fermes: [] });
            fermesParSens.get(s).fermes.push(x);
          } else if (e.type === "deplace") {
            // Un arrêt reporté reste desservi, un peu plus loin : ce n'est pas une coupure.
            fiche.effets.push({ effet: "arret-deplace", sens: s, de: x.nom });
          } else {
            marquer(props, "arret-non-desservi", x);
            fiche.effets.push({ effet: "arret-non-desservi", sens: s, de: x.nom });
          }
        }
      }

      for (const { props, v, fermes } of fermesParSens.values()) {
        // Sur un tracé de travaux, la position des arrêts fermés le long du tracé ne veut rien dire :
        // on ne les découpe pas en blocs.
        for (const b of horsTrace(v, fermes) ? [fermes] : blocsConsecutifs(v, fermes)) fermer(props, v, b, "deviation");
      }
    }

    // On ne garde sur la carte que ce qui touche la circulation : un ascenseur en travaux
    // ou une information tarifaire n'ont rien à y faire.
    // Les lignes absentes du réseau préparé (cars du Rhône, Junior Direct) restent hors carte.
    if (fiche.effets.length) perturbations.push(fiche);
    // Une annonce de reprise (« la circulation reprend progressivement ») n'a rien à placer.
    else if (ligne && a.typeseverite !== "OTHER_EFFECT" && !RE_REPRISE_ANNONCEE.test(texte)) nonPlacees.push(fiche);
    else if (!ligne) horsReseau++;
  }

  return {
    type: "FeatureCollection",
    features: fusionnerSens(features),
    meta: {
      maintenant,
      reseau: reseau.genere,
      alertes: lues.length,
      horsReseau,
      perturbations,
      nonPlacees,
    },
  };
}
