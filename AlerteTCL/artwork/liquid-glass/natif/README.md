# Logo en vraie 3D

Ouvrir `../../blender/Logo_Verre_Natif.blend`. Ce fichier conserve les maillages du tram et sa caméra et reconstruit le radar avec un cadran, une couronne de cristal à section arrondie, un secteur de balayage, trois cercles et deux repères. La couronne est un volume fermé dont les normales et le volume ont été contrôlés.

Le blanc opalin, le corail, le verre bleuté, les joints sombres et les phares disposent de matériaux distincts. Le radar utilise des couleurs de sommets et des nœuds procéduraux. Aucune texture d’image n’est utilisée ; le compositeur est désactivé. Un panneau blanc 3D derrière le radar permet au verre de transmettre un fond clair.

La vue principale de Blender montre les véritables matériaux avec Cycles. Une deuxième vue permet d’inspecter les volumes du tram en mode solide. Si Blender repasse en mode solide au chargement, activer la dernière sphère en haut à droite de la vue principale pour retrouver le verre et les lumières.

`Logo_Verre_Natif_1800.png` est uniquement une image de contrôle produite par cette scène, pas une pièce importée dans le modèle. `verification.json` indique le nombre d’objets, l’absence de textures d’images et le contrôle de la couronne.

Reconstruction :

```sh
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/logo_verre_natif.py -- --final
```

Ce fichier Blender n’est pas importable comme maillage dans Icon Composer. Le flux Apple documenté utilise des couches SVG ou PNG ; la proposition précédente avait aplati le tram en PNG et n’est pas utilisée ici.
