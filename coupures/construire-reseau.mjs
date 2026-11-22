// Prépare le réseau TCL à partir des données ouvertes du Grand Lyon (accès libre, sans compte) :
// un tracé par ligne et par sens, orienté du départ vers le terminus, les lieux de chaque ligne
// (ses points d'arrêt de même nom regroupés) et leur suite dans l'ordre du parcours. Produit
// reseau.json, lu par la lecture des alertes (lib/analyse.mjs).
//
// Relancé chaque nuit par .github/workflows/coupures.yml : node coupures/construire-reseau.mjs <sortie>

import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { versMetres, versLonLat, cumul, projeter, simplifier, recoller } from "./lib/geo.mjs";
import { normaliser, ressemblance, memeRue } from "./lib/analyse.mjs";

const SORTIE = process.argv[2];
if (!SORTIE) throw new Error("usage : node coupures/construire-reseau.mjs <reseau.json>");

const WFS =
  "https://data.grandlyon.com/geoserver/sytral/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature" +
  "&outputFormat=application/json&SRSNAME=EPSG:4326&typename=sytral:";

const COUCHES_LIGNES = [
  ["tcl_sytral.tcllignemf_2_0_0", "metro"],
  ["tcl_sytral.tcllignetram_2_0_0", "tram"],
  ["rx_rhonexpress.rxligne_2_0_0", "tram"],
  ["tcl_sytral.tcllignebus_2_0_0", "bus"],
];

// Ordre de préférence des tracés : l'itinéraire nominal d'abord, les itinéraires de travaux
// ou de nuit seulement quand la ligne n'en a pas d'autre.
const PRIORITE = { NOM: 0, null: 1, NOR: 2, EXP: 3, MER: 3, ZI: 3, MAR: 3, SCO: 3, RAH: 4, AAH: 4, NAV: 4, TVX: 5, NUI: 6 };

// Un arrêt plus loin que ça du tracé n'est pas considéré comme posé dessus.
const ECART_MAX_ARRET = 120;
const TOLERANCE_SIMPLIFICATION = 4;
// Deux quais d'un même sens portant le même nom à moins de 60 m (deux accès de métro, deux poteaux
// d'un pôle bus) sont un seul arrêt.
const ECART_QUAIS = 60;

const arrondir = ([x, y]) => [Math.round(x * 1e5) / 1e5, Math.round(y * 1e5) / 1e5];

// Le GeoServer ne rend que 1 000 objets par réponse : sans pagination, des lignes de bus entières
// (15, C7, S4A…) manquent. Les couches de lignes n'ont pas de clé primaire, d'où le tri sur gid
// pour que les pages se suivent sans trou ni doublon.
const PAGE = 1000;
async function lire(couche, tri) {
  const tout = [];
  for (;;) {
    const url = `${WFS}${couche}&count=${PAGE}&startIndex=${tout.length}${tri ? `&sortBy=${tri}` : ""}`;
    const r = await fetch(url);
    if (!r.ok) throw new Error(`${couche} : ${r.status}`);
    const page = await r.json();
    tout.push(...page.features);
    const total = page.numberMatched ?? page.totalFeatures;
    if (page.features.length < PAGE || (Number.isFinite(total) && tout.length >= total)) return tout;
  }
}

const traces = [];
for (const [couche, mode] of COUCHES_LIGNES) {
  // Les trambus (TB11, TB12) sont publiés comme des bus, mais TCL les présente avec le tramway : ils
  // ont leur place dans le fond de carte, avec leurs stations.
  const modeDe = (p) => (p.famille_transport === "FUN" ? "metro" : /^TB\d/.test(p.ligne || "") ? "trambus" : mode);
  for (const f of await lire(couche, "gid")) traces.push({ ...f, mode: modeDe(f.properties) });
}
const arrets = await lire("tcl_sytral.tclarret");

// Un tracé par ligne et par sens : le parcours habituel. Les tracés de travaux (TVX) sont les
// itinéraires de déviation en vigueur cette semaine : on retient leur date de début (voir
// debutsTravaux). Quand une ligne n'a plus que son tracé de travaux, il sert de tracé de base.
const choix = new Map();
const debutsParCle = new Map();
for (const f of traces) {
  const p = f.properties;
  const sens = p.sens === "Aller" ? "A" : p.sens === "Retour" ? "R" : null;
  if (!sens) continue; // lignes interurbaines sans sens renseigné : hors du réseau urbain TCL
  const parts = f.geometry.type === "MultiLineString" ? f.geometry.coordinates : [f.geometry.coordinates];
  const pts = recoller(parts.map((part) => part.map(versMetres)));
  const longueur = cumul(pts).at(-1);
  const cle = `${p.code_ligne}|${sens}`;
  if (p.type_trace === "TVX") {
    if (!debutsParCle.has(cle)) debutsParCle.set(cle, new Set());
    if (p.date_debut) debutsParCle.get(cle).add(`${p.date_debut.slice(0, 4)}-${p.date_debut.slice(4, 6)}-${p.date_debut.slice(6, 8)}`);
  }
  const prio = PRIORITE[p.type_trace] ?? 4;
  const actuel = choix.get(cle);
  if (!actuel || prio < actuel.prio || (prio === actuel.prio && longueur > actuel.longueur)) {
    choix.set(cle, { p, sens, pts, longueur, prio, mode: f.mode, baseTravaux: p.type_trace === "TVX" });
  }
}

// Points d'arrêt par ligne commerciale et par sens, d'après le champ « desserte » (ex. « C8:A,57:R »).
const arretsParLigne = new Map();
for (const a of arrets) {
  for (const d of (a.properties.desserte || "").split(",")) {
    const [ligne, sens] = d.split(":");
    if (!ligne || !sens) continue;
    const cle = `${ligne.replace(/\.$/, "")}|${sens}`;
    if (!arretsParLigne.has(cle)) arretsParLigne.set(cle, []);
    arretsParLigne.get(cle).push(a);
  }
}

// Les morceaux d'un tracé recollés peuvent sortir dans l'ordre inverse du parcours. On oriente
// chaque sens de son origine vers sa destination, repérées parmi ses propres arrêts.
function orienter(p, pts, points) {
  const c = cumul(pts);
  const position = (nom) => {
    const n = normaliser(nom || "");
    let best = null, score = 0;
    for (const a of points) {
      const r = ressemblance(n, normaliser(a.properties.nom));
      if (r > score) { score = r; best = a; }
    }
    return score >= SEUIL_TERMINUS ? projeter(versMetres(best.geometry.coordinates), pts, c).m : null;
  };
  const o = position(p.nom_origine), d = position(p.nom_destination), milieu = c.at(-1) / 2;
  const aLEnvers = o != null && d != null ? o > d : o != null ? o > milieu : d != null ? d < milieu : false;
  return aLEnvers ? pts.slice().reverse() : pts;
}
const SEUIL_TERMINUS = 0.6;

// Lieux. Chez TCL, un lieu est la moyenne des points d'arrêt qui portent le même nom. On le
// calcule ligne par ligne : la station Perrache du métro A et celle du tram T2 sont deux lieux,
// chacun posé sur sa ligne, au lieu d'un point moyen qui ne serait sur aucune des deux. Les deux
// sens d'une ligne ne se rejoignent que s'ils sont dans la même rue (voir memeRue).
const lieux = [];
const lignes = {};
let arretsPoses = 0, arretsEcartes = 0;
const sensParCode = new Map();
for (const { p, sens, pts, mode, baseTravaux } of choix.values()) {
  const points = arretsParLigne.get(`${p.ligne}|${sens}`) || [];
  const simple = simplifier(orienter(p, pts, points), TOLERANCE_SIMPLIFICATION);
  const debutsTravaux = [...(debutsParCle.get(`${p.code_ligne}|${sens}`) || [])];
  const v = { p, sens, mode, pts: simple, c: cumul(simple), poses: [], baseTravaux, debutsTravaux };
  for (const a of points) {
    const q = versMetres(a.geometry.coordinates);
    const { m, ecart } = projeter(q, v.pts, v.c);
    if (ecart > ECART_MAX_ARRET) { arretsEcartes++; continue; }
    v.poses.push({ nom: a.properties.nom, norm: normaliser(a.properties.nom), q, m: Math.round(m) });
  }
  if (!sensParCode.has(p.code_ligne)) sensParCode.set(p.code_ligne, []);
  sensParCode.get(p.code_ligne).push(v);
}

for (const [code, tous] of sensParCode) {
  // Regroupement des points de même nom de cette ligne : deux quais d'un même sens, ou les deux
  // sens quand ils sont dans la même rue.
  const groupes = [];
  for (const v of tous) {
    for (const pt of v.poses) {
      const touches = groupes.filter((g) => g.norm === pt.norm && g.membres.some(({ pt: h, v: w }) =>
        w === v ? Math.hypot(h.q[0] - pt.q[0], h.q[1] - pt.q[1]) <= ECART_QUAIS : memeRue(h.q, w, pt.q, v)));
      const membres = [{ pt, v }, ...touches.flatMap((g) => g.membres)];
      for (const g of touches) groupes.splice(groupes.indexOf(g), 1);
      groupes.push({ norm: pt.norm, membres });
    }
  }
  for (const g of groupes) {
    const x = g.membres.reduce((t, k) => t + k.pt.q[0], 0) / g.membres.length;
    const y = g.membres.reduce((t, k) => t + k.pt.q[1], 0) / g.membres.length;
    const i = lieux.length;
    lieux.push([g.membres[0].pt.nom, ...arrondir(versLonLat([x, y]))]);
    for (const { pt } of g.membres) pt.lieu = i;
  }
  for (const v of tous) {
    v.poses.sort((x, y) => x.m - y.m);
    // Deux quais du même lieu qui se suivent ne font qu'un arrêt.
    const suite = v.poses.filter((x, k) => k === 0 || x.lieu !== v.poses[k - 1].lieu).map((x) => [x.lieu, x.m]);
    arretsPoses += suite.length;
    const l = (lignes[code] ??= { nom: v.p.ligne, mode: v.mode, couleur: v.p.couleur_hex || "#888888", sens: {} });
    l.sens[v.sens] = {
      origine: v.p.nom_origine,
      destination: v.p.nom_destination,
      trace: v.pts.map(versLonLat).map(arrondir),
      arrets: suite,
      // Le tracé de base est-il déjà un itinéraire de travaux ? Ses arrêts fermés sont alors à
      // l'écart du tracé, et le parcours habituel n'est pas publié.
      ...(v.baseTravaux ? { baseTravaux: true } : {}),
      // Dates de début des tracés de travaux de ce sens : une alerte qui démarre le même jour
      // décrit une déviation déjà intégrée aux horaires de la semaine.
      ...(v.debutsTravaux.length ? { debutsTravaux: v.debutsTravaux } : {}),
    };
  }
}

// Tous les points d'arrêt du réseau, desservis ou non : un arrêt fermé pour travaux sort de la
// desserte de sa ligne, et il faut pouvoir le retrouver quand une alerte le cite.
const vus = new Set();
const points = [];
for (const a of arrets) {
  const [lon, lat] = arrondir(a.geometry.coordinates);
  const cle = `${a.properties.nom}|${lon}|${lat}`;
  if (vus.has(cle)) continue;
  vus.add(cle);
  points.push([a.properties.nom, lon, lat]);
}

await mkdir(dirname(SORTIE), { recursive: true });
await writeFile(SORTIE, JSON.stringify({ genere: new Date().toISOString(), lieux, lignes, points }));

console.log(
  `${Object.keys(lignes).length} lignes, ${choix.size} sens, ${arretsPoses} arrêts posés, ${arretsEcartes} écartés (trop loin du tracé), ${lieux.length} lieux de ligne`
);
