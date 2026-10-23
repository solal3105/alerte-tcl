# Tram — modèle 3D natif

`Logo_Tram.blend` reprend les grandes formes du logo : cabine douce, pare-brise enveloppant, deux vitres latérales, phares ronds, sourire, bande corail et pantographe en V. La photo est une référence de style ; elle n’est pas projetée sur le modèle.

Les deux caisses ont des longueurs proches : 4,00 m à l’avant et 3,80 m à l’arrière. Elles sont construites avec la même section et le même niveau de toit à 3,04 m. Leur largeur nominale commune est de 2,30 m. Chaque caisse dispose de deux fenêtres par flanc et de deux essieux. Les vitres latérales et les bandes rouges partagent des niveaux horizontaux réels, indépendants de la caméra.

Le nez, le toit, les flancs et le bandeau bleu inférieur appartiennent à une coque continue pour chaque caisse. Le bleu inférieur est une affectation de matériau sur cette coque, sans pièce superposée. Les roues possèdent des passages arrondis individuels et des alésages d’essieu ; aucune grande découpe rectangulaire ne casse le contour du bas de caisse.

Les vitrages sont des solides encastrés dans de vraies poches, avec joints séparés. Les phares possèdent des logements, des cerclages et des lentilles distinctes. Les pièces et matériaux restent éditables.

## Finition

Le fichier comprend maintenant des matériaux PBR : blanc porcelaine verni, bande corail laquée, bas de caisse bleu graphite, gomme mate, pantographe métallique satiné et vitres bleu profond opaques (transmission nulle, alpha 1). Les vitres reflètent réellement les éclairages de studio. Les lentilles des phares émettent une lumière jaune chaude, complétée par deux faisceaux doux.

La collection `80 Studio - finition` contient les éclairages et le fond courbe avec ombres de contact. Elle peut être masquée indépendamment du tram. Le rendu final Cycles est enregistré dans `Tram_Finition.png` en 2048 × 2048 pixels. Les proportions validées du modèle restent identiques.

## Utilisation

- **Tram - 3D** : aperçu des matériaux en trois quarts, avec orbite libre.
- **Tram - Profil** : vue orthographique latérale pour contrôler les niveaux sans effet de perspective.
- **Tram - Rendu** : image finale embarquée dans le fichier.

L’image d’origine reste embarquée pour référence. Tous les matériaux, éclairages et paramètres de rendu sont éditables dans Blender.

## Reconstruction par code

`modele_tram.py` construit et vérifie le modèle. `tram_geometry.py` fournit les primitives de maillage. Les dimensions communes sont regroupées en tête du constructeur ; les détails sont définis en coordonnées locales X/Z ou Y/Z.

```sh
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/modele_tram.py
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/finition_tram.py
```

La première commande reconstruit la géométrie et réinitialise la présentation. La seconde applique la finition et calcule le rendu final ; `-- --preview` génère un aperçu rapide sans remplacer le fichier Blender. `verification_finition.json` confirme l’opacité des vitres, l’émission des phares et la conservation des dimensions des pièces.

L’enregistrement n’a lieu que si les contrôles passent : maillages fermés, absence de faces dégénérées, volumes orientés correctement, vitrages dégagés de leurs parois, lentilles dégagées de leurs cerclages, roues dégagées des coques et toitures réellement alignées. Les résultats sont dans `verification.txt` et `verification_geometrie.json`.

Les anciennes étapes sont conservées dans `archive_v1/`, `archive_v2_structure/`, `archive_v3_arrondis/`, `archive_v4_caisse_courte/` et `archive_v5_proportions_validees/`. Elles ne sont pas utilisées pour reconstruire le modèle actuel.
