# Tram du logo — modèle Blender

- **Logo_Tram.blend** : scène modifiable, référence embarquée, caméra et éclairage prêts.
- **logo_tram_render.png** : rendu 1024 × 1024.
- **modele_tram.py** : script qui reconstruit la scène.
- **verification.txt** : contrôle des coques et des épaisseurs des vitrages.

La silhouette et la palette reprennent l’icône de l’application. Les détails sont reconstruits en 3D pour pouvoir les peaufiner : aucune texture du logo n’est appliquée au modèle. Les parties invisibles dans la référence sont interprétées.

Le fichier final est enregistré avec **Blender 4.5.14 LTS**, la version ouverte sur ce Mac.

## Retouches

Les pièces sont rangées dans les collections Carrosserie, Vitrages, Phares, Livrée et accessoires, Pantographe, Châssis et roues. L’objet parent **TRAM · déplacer ou tourner le modèle ici** permet de déplacer tout le tram indépendamment du décor.

Les coques principales sont des volumes fermés composés de quadrilatères, avec un modificateur de subdivision conservé. Les vitrages ont des joints séparés et une épaisseur réglable. Les phares possèdent des cerclages, des réflecteurs et des lentilles distincts.

- Matériau **05 · Vitrage bleu** : couleur, rugosité, vernis ; les reflets viennent des lumières.
- Matériau **08 · Lentille jaune** : couleur et intensité lumineuse des phares.
- Pantographe et essuie-glace : courbes 3D à épaisseur réglable.
- Collection **07 · Décor** : fond circulaire et ombre stylisée, séparés du modèle.
- Collection **09 · Référence** : image originale embarquée, masquée au rendu.

`Pavé numérique 0` affiche la caméra. `F12` lance le rendu. Le texte **À LIRE · Modèle du tram** est également présent dans le fichier Blender.

## Reconstruire la scène

Depuis la racine du projet :

```sh
"/Users/solalgendrin/archi-interieur/tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python artwork/blender/modele_tram.py -- --render
```

Ajouter `--preview` pour un aperçu à 640 pixels. Le script remplace le `.blend` et le rendu du dossier.
