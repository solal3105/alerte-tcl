// Lecture des alertes du dimanche 22 novembre 2026, 11 h 22, sur un extrait du réseau (lignes B, C,
// D, T3, T4, C8, 36 et 38). Lancer : node --test coupures/test/*.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { preparerReseau, analyser, identiteAlerte, lireCalendrier } from "../lib/analyse.mjs";
import { publier, memeContenu } from "../lib/publication.mjs";

const lire = (nom) => JSON.parse(readFileSync(new URL(nom, import.meta.url), "utf8"));
const reseau = preparerReseau(lire("reseau-extrait.json"));
const alertes = lire("alertes-22-novembre.json").values;
const MAINTENANT = "2026-11-22 11:22:09";
const publie = publier(analyser(alertes, reseau, MAINTENANT), "2026-11-22T10:22:09.000Z");
const de = (ligne) => publie.coupures.filter((c) => c.ligne === ligne);
const noms = (c, sens) => c.arrets.filter((a) => !sens || a.sens === sens).map((a) => a.nom);

test("le métro B interrompu sur toute la ligne est placé, avec toutes ses stations", () => {
  const [b] = de("B");
  assert.equal(b.gravite, "NO_SERVICE");
  assert.deepEqual(b.fenetres, [{ debut: "2026-11-22 04:30:00", fin: "2026-11-22 13:00:00" }]);
  assert.ok(b.effets.every((e) => e.effet === "interruption" && e.toute));
  assert.equal(b.traits.length, 1);
  assert.ok(b.traits[0].deuxSens);
  assert.ok(noms(b).includes("Saxe - Gambetta"));
  assert.ok(noms(b).length >= 10);
});

test("la D ne roule que de Gare de Vaise à Saxe-Gambetta, les lundis et mardis dès 21 h 20", () => {
  const [d] = de("D");
  assert.deepEqual(d.fenetres, [
    { debut: "2026-11-23 21:20:00", fin: "2026-11-24 01:30:00" },
    { debut: "2026-11-24 21:20:00", fin: "2026-11-25 01:30:00" },
  ]);
  assert.equal(d.horairesPartiels, false);
  const fermes = new Set(noms(d));
  for (const n of ["Garibaldi", "Grange Blanche", "Gare de Vénissieux"]) assert.ok(fermes.has(n), n);
  for (const n of ["Saxe - Gambetta", "Gare de Vaise-G.Collomb", "Bellecour"]) assert.ok(!fermes.has(n), n);
  assert.equal(d.bornes.length, 1);
});

test("la station La Soie de la T3 n'est fermée que vers Meyzieu", () => {
  const soie = de("T3").find((c) => c.titre.includes("La Soie"));
  assert.deepEqual(soie.arrets.map(({ nom, sens }) => [nom, sens]), [["Vaulx-en-Velin La Soie", "A"]]);
  assert.equal(soie.traits.length, 0);
});

test("la T3 du soir suit les dates de l'alerte et signale le titre qui les contredit", () => {
  const soir = de("T3").find((c) => c.effets.some((e) => e.effet === "interruption"));
  assert.deepEqual(soir.fenetres, [{ debut: "2026-11-23 20:30:00", fin: "2026-11-24 01:30:00" }]);
  assert.equal(soir.datesContradictoires, true);
  assert.ok(publie.coupures.filter((c) => c !== soir).every((c) => !c.datesContradictoires));
});

test("une déviation déjà dans les horaires et un arrêt reporté ne sont pas des coupures", () => {
  for (const c of publie.coupures) assert.ok(c.effets.every((e) => !e.integree && e.effet !== "arret-deplace"), c.ligne);
  // Le report de l'arrêt Musée des Confluences (36) n'apparaît pas ; sa limitation à Jean Jaurès, si.
  assert.deepEqual(de("36").map((c) => c.effets.map((e) => e.effet)), [["limitation", "limitation"]]);
});

test("une alerte terminée disparaît, une alerte à venir garde ses fenêtres", () => {
  const apres = publier(analyser(alertes, reseau, "2026-11-22 13:30:00"), "x");
  assert.equal(apres.coupures.filter((c) => c.ligne === "B").length, 0);
  assert.equal(apres.coupures.filter((c) => c.ligne === "D").length, 1);
});

test("l'identité d'une alerte est celle des applications", () => {
  // Même valeur dans AlertIdentityTest (module partagé).
  const a = { ligne_com: "D", ligne_cli: "D", titre: "Titre", debut: "2026-11-23 21:20:00", message: "Métro D ne circule pas." };
  assert.equal(identiteAlerte(a), "D|D|Titre|2026-11-23 21:20:00|c4c01b3c");
  assert.equal(identiteAlerte({ ...a, message: "" }), "D|D|Titre|2026-11-23 21:20:00|811c9dc5");
});

test("une alerte sans précision d'heure garde la période publiée", () => {
  const { fenetres, restreint } = lireCalendrier({ titre: "Travaux", message: "La ligne ne circule pas.", debut: "2026-11-23 04:30:00", fin: "2026-11-24 01:30:00" });
  assert.equal(restreint, false);
  assert.deepEqual(fenetres, [{ debut: "2026-11-23 04:30:00", fin: "2026-11-24 01:30:00" }]);
});

test("deux publications qui ne diffèrent que par l'heure ont le même contenu", () => {
  assert.ok(memeContenu(publie, { ...publie, genere: "2026-11-22T11:00:00.000Z" }));
  assert.ok(!memeContenu(publie, { ...publie, coupures: publie.coupures.slice(1) }));
});
