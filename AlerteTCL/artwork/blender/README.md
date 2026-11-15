# Tram — modèle 3D natif

La correction **entièrement 3D** se trouve dans `Logo_Verre_Natif.blend` ; voir [`../liquid-glass/natif/README.md`](../liquid-glass/natif/README.md). L’ancienne proposition `Logo_App_LiquidGlass.blend` et le document Apple à images sont conservés comme étapes précédentes.

`Logo_Tram.blend` reprend les grandes formes du logo : cabine douce, pare-brise enveloppant, deux vitres latérales, phares ronds, sourire, bande corail et pantographe en V. La photo est une référence de style ; elle n’est pas projetée sur le modèle.

Les deux caisses ont des longueurs proches : 4,00 m à l’avant et 3,80 m à l’arrière. Elles sont construites avec la même section et le même niveau de toit à 3,04 m. Leur largeur nominale commune est de 2,30 m. Chaque caisse dispose de deux fenêtres par flanc et de deux essieux. Les vitres latérales et les bandes rouges partagent des niveaux horizontaux réels, indépendants de la caméra.

Le nez, le toit, les flancs et le bandeau bleu inférieur appartiennent à une coque continue pour chaque caisse. Le bleu inférieur est une affectation de matériau sur cette coque, sans pièce superposée. Les roues possèdent des passages arrondis individuels et des alésages d’essieu ; aucune grande découpe rectangulaire ne casse le contour du bas de caisse.

Les vitrages sont des solides encastrés dans de vraies ouvertures traversantes, avec joints séparés. Les caisses sont creuses et comportent un intérieur simple : sol, sièges, mains courantes et poste de conduite. Les phares possèdent des logements, des cerclages et des lentilles distinctes. Les pièces et matériaux restent éditables.

## Finition

Le fichier comprend des matériaux PBR : blanc porcelaine verni, bande corail laquée, bas de caisse bleu graphite, gomme mate, pantographe métallique satiné et verre transparent légèrement bleuté (transmission 1, métal 0, indice 1,45). Le verre possède une épaisseur réelle et laisse voir l’habitacle, avec des reflets et de la réfraction. Les lentilles des phares émettent une lumière jaune chaude, complétée par deux faisceaux doux.

La collection `80 Studio - finition` contient les éclairages et le fond courbe avec ombres de contact. Elle peut être masquée indépendamment du tram. Le rendu final Cycles est enregistré dans `Tram_Finition.png` en 2048 × 2048 pixels. Les proportions validées du modèle restent identiques.

## Utilisation

- **Tram - 3D** : aperçu Cycles en trois quarts, avec orbite libre et transparence réelle.
- **Tram - Profil** : vue orthographique latérale pour contrôler les niveaux sans effet de perspective.
- **Tram - Rendu** : image finale embarquée dans le fichier.

L’image d’origine reste embarquée pour référence. Tous les matériaux, éclairages et paramètres de rendu sont éditables dans Blender.

## Rendu pour l’icône d’application

### Scène complète à ouvrir

**`Logo_App_Scene_3D.blend` est la version complète en 3D.** Le radar est composé de douze objets natifs éditables : disque épais à bord arrondi, surface verte, secteur bleu, trois anneaux de distance, liseré, rayon et deux balises avec leurs halos. Ses dégradés utilisent des couleurs de sommets. Aucun fond bitmap n’est utilisé et le compositeur est désactivé. Le radar possède un éclairage dédié avec des ombres physiques.

Le tram, ses matériaux et la caméra sont conservés. Le fichier s’ouvre dans **Tram - 3D**, en vue caméra Cycles, avec les lumières de la scène et le verre transmissif. Une orbite permet de voir l’épaisseur du disque et les éléments du radar. **Logo - Rendu** contient le rendu de cette même scène. Les exports correspondants sont `../app-icon/AlerteTCL_3D_2048.png`, `AlerteTCL_3D_1024.png` et `AlerteTCL_3D_64.png`.

```sh
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/scene_logo_3d.py -- --final
```

Sans `-- --final`, le script crée la scène et un aperçu de 768 pixels. `verification_scene_3d.json` décrit la géométrie du radar, le vitrage et l’absence de composition 2D.

### Ancienne composition conservée

`Logo_App_Tram.blend` contient une composition dédiée, lumineuse et colorée : cadrage carré en trois quarts proche de la face, carrosserie blanche, bande corail vive, contours bleu nuit, radar vert pomme et balayage bleu ciel. La géométrie du modèle fini est conservée. Le verre bleu garde un reflet net (transmission 0,90, rugosité 0,035) et laisse voir l’habitacle. Un éclairage frontal doux renforce le blanc de la cabine. Les phares sont allumés et les ombres sont contenues dans le disque.

`radar_background.py` construit le fond par formes analytiques : trois anneaux espacés, balayage bleu ciel avec une traînée fondue et deux pastilles de localisation. Le bord menthe et les pastilles possèdent un dégradé de lumière doux. Le fond est calculé à la résolution du rendu et embarqué dans le fichier Blender. Le compositeur applique le traitement de couleurs Khronos PBR Neutral au tram seul pour conserver des couleurs vives et laisser le fond indépendant de l’éclairage 3D.

Les exports se trouvent dans `../app-icon/` : `AlerteTCL_Icon_2048.png` est le rendu maître, `AlerteTCL_Icon_1024.png` est l’icône au format de l’asset iOS et `AlerteTCL_Icon_64.png` permet de contrôler la lisibilité en petit. Les PNG sont en RGB, sans canal alpha. L’asset existant de l’application reste indépendant de ces exports. L’espace **Logo - Rendu** affiche l’image finale embarquée.

Pour reproduire le rendu à partir de `Logo_Tram.blend` :

```sh
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/rendu_logo_app.py
```

Ajouter `-- --preview` produit un aperçu en 768 pixels sans remplacer les livrables finaux. `verification_logo.json` enregistre les dimensions d’export, le vitrage, le radar et les limites projetées du modèle dans le cadre. Les propositions précédentes sont conservées dans `../app-icon/archive_v1_medaillon/` et `../app-icon/archive_v2_radar_instrument/`.

## Reconstruction par code

`modele_tram.py` construit et vérifie le modèle. `tram_geometry.py` fournit les primitives de maillage. Les dimensions communes sont regroupées en tête du constructeur ; les détails sont définis en coordonnées locales X/Z ou Y/Z.

```sh
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/modele_tram.py
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/finition_tram.py
```

La première commande reconstruit la géométrie et réinitialise la présentation. La seconde appelle `vitrage_tram.py` pour les ouvertures et l’intérieur, applique la finition et calcule le rendu final ; `-- --preview` génère un aperçu rapide sans remplacer le fichier Blender. `verification_finition.json` confirme la transmission du verre et l’émission des phares. `verification_vitrage.json` contrôle les coques après ouverture, les passages derrière chaque vitre et la conservation des dimensions extérieures.

L’enregistrement n’a lieu que si les contrôles passent : maillages fermés, absence de faces dégénérées, volumes orientés correctement, vitrages dégagés de leurs parois, lentilles dégagées de leurs cerclages, roues dégagées des coques et toitures réellement alignées. Les résultats sont dans `verification.txt` et `verification_geometrie.json`.

Les anciennes étapes sont conservées dans `archive_v1/`, `archive_v2_structure/`, `archive_v3_arrondis/`, `archive_v4_caisse_courte/`, `archive_v5_proportions_validees/` et `archive_v6_vitres_opaques/`. Elles ne sont pas utilisées pour reconstruire le modèle actuel.
