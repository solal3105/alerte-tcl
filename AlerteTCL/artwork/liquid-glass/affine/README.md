# Icône corrigée dans Icon Composer

Ouvrir `../AlerteTCL_Verre_Corrige.icon` dans Icon Composer.

Quatre groupes, conformément à la limite Apple : essuie-glace, vitres, tram, radar. Huit couches séparées : essuie-glace, vitres, caisse avant, caisse arrière, anneaux, balayage, couronne et cadran. Les balises supprimées pendant la revue ne sont pas réintroduites.

Les deux caisses sont de nouvelles projections PNG du modèle `../../blender/Logo_Verre_Natif.blend`. Leur masquage utilise des passes AOV afin de conserver l’occlusion des pièces. Les cinq vitres SVG suivent la projection des maillages de vitrage. Les vitres visibles ont été retirées du rendu des caisses : leur teinte, leur transparence, leur flou et leurs reflets sont appliqués par Icon Composer. L’essuie-glace est une couche séparée au-dessus de la vitre. Les phares restent lumineux dans le rendu de la caisse avant.

Le radar est composé de SVG distincts, avec des repères fins et un bord en verre. L’effet spéculaire Apple est désactivé sur la carrosserie pour supprimer l’ancien contour brillant autour de tout le tram.

Ce document contient des images et des vecteurs superposés, pas des maillages 3D : c’est le format pris en charge par Icon Composer. La scène native Blender et l’ancienne icône sont conservées. Aucune cible Xcode n’a été modifiée.

Reconstruction (fermer le document Apple avant de remplacer ses fichiers) :

```sh
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/export_icon_affine.py
python3 artwork/liquid-glass/assemble_icon_affine.py
```

`Apple_Default.png` est le rendu du moteur Apple utilisé pour le contrôle visuel. `AlerteTCL_Verre_Affine.icon` reste une copie intermédiaire à huit groupes, conservée avec les modifications faites pendant sa revue. La version à utiliser est `AlerteTCL_Verre_Corrige.icon`.
