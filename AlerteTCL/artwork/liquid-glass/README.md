# AlerteTCL — variante Liquid Glass

**Document Icon Composer corrigé : `AlerteTCL_Verre_Corrige.icon`.** Les deux caisses, l’essuie-glace, les vitres et le radar sont répartis en huit couches et quatre groupes. Les cinq vitres visibles sont des formes SVG projetées du modèle, avec les matériaux Apple appliqués directement dans Icon Composer. La carrosserie n’a plus de contour spéculaire Apple. Voir [`affine/README.md`](affine/README.md).

**La proposition précédente `AlerteTCL_LiquidGlass.icon` est conservée comme archive.** Elle utilisait un PNG unique du tram. Les vrais maillages restent dans `../blender/Logo_Verre_Natif.blend`, décrit dans [`natif/README.md`](natif/README.md).

Variante distincte ; les scènes et l’icône existantes sont conservées.

- `AlerteTCL_LiquidGlass.icon` : document Apple éditable à ouvrir dans Icon Composer. Quatre groupes, cinq images alignées : le tram, les anneaux, les balises, le balayage et le disque. Les SVG du radar restent vectoriels. Le tram est exporté en PNG transparent depuis la scène Blender.
- `../blender/Logo_App_LiquidGlass.blend` : scène native complète avec coque opaline, éléments corail translucides, vitrage bleu, phares lumineux et radar en vraie géométrie. Le compositeur est désactivé. Les matériaux, lumières et volumes restent éditables.
- `AlerteTCL_LiquidGlass_1600.png` : rendu de la scène Blender complète.
- `Apple_Default.png`, `Apple_Dark.png`, `Apple_ClearLight.png`, `Apple_TintedDark.png` : aperçus produits par le moteur Apple à partir du fichier `.icon`.

Le document Apple et la scène Blender sont deux représentations du même dessin : Apple utilise des images sur plusieurs couches pour appliquer ses effets dynamiques ; le `.blend` contient les vrais volumes 3D. Le fichier Apple n’est pas une simple image de l’icône complète. Ses paramètres de transparence, diffusion et ombre sont réglés par groupe.

Le document a été ouvert dans Icon Composer 1.2 (version installée avec Xcode) et ses quatre apparences ont été exportées avec `ictool`. Il n’a pas été testé dans un simulateur iOS 27. Apple indique que les documents Icon Composer existants reçoivent automatiquement le nouveau matériau dans la version récente : https://developer.apple.com/icon-composer/

Dans Blender, utiliser l’espace `Tram - 3D`, puis le mode **Rendu** (dernière sphère en haut à droite) si Blender revient au mode solide à l’ouverture. Le mode Rendu affiche la transmission du verre et les éclairages de la scène. L’espace `Logo - Rendu` contient le PNG final.

Reconstruction de la variante et du calque du tram :

```sh
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/logo_liquid_glass.py -- --final --layers
python3 artwork/liquid-glass/assemble_icon.py
```

Fermer le document dans Icon Composer avant d’exécuter `assemble_icon.py`, car ce script reconstruit ses réglages à partir des sources. Le fichier `.icon` peut être ajouté à Xcode séparément ; la cible de l’application n’a pas été modifiée.
