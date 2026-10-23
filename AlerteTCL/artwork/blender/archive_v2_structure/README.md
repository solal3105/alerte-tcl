# Tram — modélisation uniquement

**Logo_Tram.blend** contient le tram reconstruit par code, enregistré avec Blender 4.5.14. La scène s’ouvre en vue de travail orthographique. Elle ne contient ni caméra, ni éclairage, ni décor.

## Construction

Les deux caisses partagent une section de 2,30 m de large, une toiture à 3,03 m et un plancher à 0,75 m. Le nez est une coque creuse raccordée à cette section ; la seconde caisse conserve les mêmes dimensions transversales.

Les fenêtres, les portes et l’intercirculation sont des ouvertures dans les parois. Les vitrages sont en retrait, dans des joints avec lèvre et feuillure arrière. Chaque porte possède deux vantaux distincts, leurs vitres et leurs poignées. Le plancher se prolonge dans le nez et jusqu’à la face arrière, et rejoint la passerelle entre les caisses.

Trois bogies à deux essieux portent les caisses, dont un bogie partagé sous l’articulation. Les douze roues ont un boudin et un alésage autour de l’essieu. Les boîtes d’essieu sont à l’intérieur des roues, avec un dégagement vérifié. Les roues et la caisse conservent 70 mm de dégagement vertical.

Les logements des phares sont réellement découpés. Chaque boîtier, réflecteur et lentille utilise le même axe local, calculé sur le nez. Le pantographe est constitué de deux cadres longitudinaux avec axes transversaux et archet, porté par quatre isolateurs posés sur le toit.

Il s’agit d’un tram stylisé inspiré de l’icône, pas d’un plan de fabrication. Les couleurs servent à distinguer les pièces en vue de travail.

## Code

- `modele_tram.py` : dimensions communes, ouvertures, assemblages et hiérarchie.
- `tram_geometry.py` : primitives de géométrie, parois, profils tournés, vitrages et joints.
- `verification_modele.py` : contrôle des maillages évalués et des dégagements réels.

Les dimensions principales sont regroupées dans `Dimensions`. Les implantations des fenêtres et des portes sont définies dans `front_features` et `rear_features`. Les caisses, les bogies, les vitrages et le pantographe restent des pièces distinctes. La collection `90 Outils de decoupe`, masquée, contient les outils des booléens non destructifs du nez.

Depuis la racine du projet :

```sh
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/modele_tram.py
```

Le script reconstruit la scène et remplace le `.blend` uniquement si les contrôles passent. Il ne lance aucun rendu.

## Vérification

`verification.txt` résume les contrôles ; `verification_geometrie.json` contient leurs résultats détaillés : volumes fermés, faces non dégénérées, vitrages sans intersection avec les parois, lentilles dans leurs boîtiers, roues dégagées des caisses et des pièces de bogie, niveaux communs des planchers et toitures, brides raccordées aux cloisons, appuis du pantographe.

L’ancienne version, son script et son image sont conservés dans `archive_v1/` pour permettre de revenir en arrière.
