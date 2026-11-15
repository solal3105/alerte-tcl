# Tram — modèle 3D natif

`Logo_Tram.blend` reprend les grandes formes du logo : cabine douce, pare-brise enveloppant, deux vitres latérales, phares ronds, sourire, bande corail et pantographe en V. La photo est une référence de style ; elle n’est pas projetée sur le modèle.

Les deux caisses sont construites avec la même section et le même niveau de toit à 3,04 m. Leur largeur nominale commune est de 2,30 m. Les vitres latérales et les bandes rouges partagent des niveaux horizontaux réels, indépendants de la caméra.

Le nez, le toit, les flancs et le bandeau bleu inférieur appartiennent à une coque continue pour chaque caisse. Le bleu inférieur est une affectation de matériau sur cette coque, sans pièce superposée. Les roues possèdent des passages arrondis individuels et des alésages d’essieu ; aucune grande découpe rectangulaire ne casse le contour du bas de caisse.

Les vitrages sont des solides encastrés dans de vraies poches, avec joints séparés. Les phares possèdent des logements, des cerclages et des lentilles distinctes. Les pièces et matériaux restent éditables.

## Utilisation

- **Tram - 3D** : vue de travail en trois quarts, avec orbite libre.
- **Tram - Profil** : vue orthographique latérale pour contrôler les niveaux sans effet de perspective.

L’image d’origine est embarquée dans le fichier pour référence. La scène n’a aucun éclairage ni décor ; la caméra sert seulement à retrouver une vue de travail.

## Reconstruction par code

`modele_tram.py` construit et vérifie le modèle. `tram_geometry.py` fournit les primitives de maillage. Les dimensions communes sont regroupées en tête du constructeur ; les détails sont définis en coordonnées locales X/Z ou Y/Z.

```sh
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/modele_tram.py
```

L’enregistrement n’a lieu que si les contrôles passent : maillages fermés, absence de faces dégénérées, volumes orientés correctement, vitrages dégagés de leurs parois, lentilles dégagées de leurs cerclages, roues dégagées des coques et toitures réellement alignées. Les résultats sont dans `verification.txt` et `verification_geometrie.json`.

Les anciennes étapes sont conservées dans `archive_v1/`, `archive_v2_structure/` et `archive_v3_arrondis/`. Elles ne sont pas utilisées pour reconstruire le modèle actuel.
