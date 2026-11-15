# Tram du logo — modèle Blender

`Logo_Tram.blend` reprend le caractère de l’icône de l’application : cabine douce et arrondie, grand pare-brise bleu, deux larges vitres latérales sur la caisse avant, phares ronds, sourire creusé, bande corail et pantographe compact en V. La construction se fait entièrement par code. La scène contient uniquement le modèle et s’ouvre en vue de travail ; aucune caméra, aucun éclairage, aucun décor ni rendu.

## Proportions conservées

Les deux caisses gardent la largeur de 2,30 m, le toit à 3,03 m, le plancher à 0,75 m et les mêmes implantations longitudinales que la version de structure. Les coins de carrosserie et le raccord du nez aux flancs sont davantage arrondis. Les détails mécaniques des trois bogies restent sous la caisse ; les roues sont bleu foncé.

Les vitres occupent des ouvertures réelles, avec joints et feuillures. Le sourire et les logements des phares sont découpés dans le nez. Les rubans corail sont des pièces fines suivant les surfaces du modèle. Les cloisons d’intercirculation se placent à l’intérieur des coques pour éviter les faces extérieures superposées.

La scène est une reconstruction stylisée du tram du logo, pas un plan de fabrication. Les couleurs sont de simples repères de matériaux pour la vue de travail.

## Construction et vérification

- `modele_tram.py` : proportions, formes et assemblages ; paramètres principaux dans `Dimensions`.
- `tram_geometry.py` : primitives de maillage, surfaces et profils.
- `verification_modele.py` : vérifications sur la géométrie évaluée après modificateurs.
- `verification.txt` et `verification_geometrie.json` : résultats du dernier lancement.

Depuis la racine du projet :

```sh
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/modele_tram.py
```

Le script n’enregistre le fichier qu’après validation : maillages fermés sans faces dégénérées, vitrages sans intersection avec leurs parois, lentilles dans leurs logements, roues dégagées des caisses et des pièces de bogie, niveaux communs des planchers et toitures, contact des brides et appuis du pantographe. Ces contrôles mesurent la construction ; la fidélité des formes au logo est examinée en vue de travail.

`archive_v1/` conserve la première reconstruction et son rendu ancien. `archive_v2_structure/` conserve la version de structure précédant le retour aux formes du logo, ainsi qu’une sauvegarde de sa session Blender.
