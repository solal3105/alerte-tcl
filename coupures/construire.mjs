// Lit les alertes trafic TCL et écrit coupures.json, que le relais distribue aux applications.
// Lancé toutes les 5 minutes par .github/workflows/coupures.yml.
//
//   node coupures/construire.mjs <reseau.json> <coupures.json> [alertes.json]
//
// Sans fichier d'alertes, elles sont lues sur le relais (sa copie de /alerts, qui n'ajoute aucune
// requête chez Grand Lyon). Le fichier n'est réécrit que si son contenu change, ou une fois par heure
// pour dire aux applications que la lecture tourne toujours (voir README.md, « Fraîcheur »).

import { readFile, writeFile } from "node:fs/promises";
import { preparerReseau, analyser } from "./lib/analyse.mjs";
import { publier, memeContenu } from "./lib/publication.mjs";

const RELAIS = "https://tcl-proxy.solalgendrin.workers.dev/alerts";
const BATTEMENT_MS = 60 * 60 * 1000;

const [cheminReseau, sortie, cheminAlertes] = process.argv.slice(2);
if (!cheminReseau || !sortie) throw new Error("usage : node coupures/construire.mjs <reseau.json> <coupures.json> [alertes.json]");

async function lireAlertes() {
  if (cheminAlertes) return JSON.parse(await readFile(cheminAlertes, "utf8")).values;
  const r = await fetch(RELAIS, { headers: { "User-Agent": "AlerteTCL/coupures", Accept: "application/json" } });
  if (!r.ok) throw new Error(`relais : ${r.status}`);
  const { values } = await r.json();
  // Une réponse vide est une panne du flux, pas un réseau sans perturbation : on garde la
  // publication précédente plutôt que d'effacer toutes les coupures.
  if (!Array.isArray(values) || !values.length) throw new Error("relais : aucune alerte reçue");
  return values;
}

const reseau = preparerReseau(JSON.parse(await readFile(cheminReseau, "utf8")));
const nouveau = publier(analyser(await lireAlertes(), reseau));
const ancien = await readFile(sortie, "utf8").then(JSON.parse, () => null);

if (ancien && memeContenu(ancien, nouveau) && Date.now() - Date.parse(ancien.genere) < BATTEMENT_MS) {
  console.log(`inchangé depuis ${ancien.genere}`);
} else {
  await writeFile(sortie, JSON.stringify(nouveau));
  console.log(`${nouveau.coupures.length} coupures, ${nouveau.nonPlacees.length} sans tracé`);
}
