// Ce que les applications reçoivent : coupures.json, une entrée par alerte qui coupe quelque chose
// (ligne qui ne circule pas, tronçon fermé, arrêt non desservi), avec ses fenêtres, ses tracés
// coupés et ses arrêts. Les déviations sans arrêt fermé, les arrêts reportés et les itinéraires de
// travaux déjà dans les horaires n'y sont pas : rien n'y est coupé. Format : README.md.

export const FORMAT = 1;

// Une alerte « ne circule pas » que le texte ne permet pas de placer garde sa pastille dans
// l'application, sans griser de ligne.
const SANS_SERVICE = "NO_SERVICE";

const fenetres = (p) => p.fenetres.map(({ debut, fin }) => ({ debut, fin: fin ?? null }));

function entree(p) {
  return {
    id: p.id,
    ligne: p.ligne,
    mode: p.mode,
    couleur: p.couleur,
    titre: p.titre,
    message: p.message,
    debut: p.debut,
    fin: p.fin ?? null,
    fenetres: fenetres(p),
    horairesPartiels: p.horairesPartiels,
    datesContradictoires: p.datesContradictoires,
    gravite: p.gravite,
    destinations: p.destinations,
  };
}

const effetsCoupants = (p) => p.effets.filter((e) => !e.integree && e.effet !== "arret-deplace")
  .map(({ morceaux, ...e }) => e);

export function publier(resultat, genere = new Date().toISOString()) {
  const parId = new Map();
  for (const f of resultat.features) {
    const { id, effet, sens, nom, dansTroncon, deuxSens } = f.properties;
    if (!parId.has(id)) parId.set(id, { traits: [], arrets: [], bornes: [] });
    const g = parId.get(id);
    const [lon, lat] = f.geometry.type === "Point" ? f.geometry.coordinates : [];
    if (effet === "interruption") g.traits.push({ sens, deuxSens: !!deuxSens, points: f.geometry.coordinates });
    else if (effet === "arret-non-desservi") g.arrets.push({ nom, sens, lon, lat, dansTroncon: !!dansTroncon });
    else if (effet === "arret-borne") g.bornes.push({ nom, sens, lon, lat });
  }
  const coupures = resultat.meta.perturbations
    .filter((p) => parId.get(p.id)?.traits.length || parId.get(p.id)?.arrets.length)
    .map((p) => ({ ...entree(p), effets: effetsCoupants(p), ...parId.get(p.id) }));
  const nonPlacees = resultat.meta.nonPlacees.filter((p) => p.gravite === SANS_SERVICE).map(entree);
  return { format: FORMAT, genere, reseau: resultat.meta.reseau, coupures, nonPlacees };
}

// Deux publications qui ne diffèrent que par leur heure de calcul disent la même chose.
export const memeContenu = (a, b) => JSON.stringify({ ...a, genere: null }) === JSON.stringify({ ...b, genere: null });
