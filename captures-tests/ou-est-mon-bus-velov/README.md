# Captures d'écran : où est mon bus et stations Vélo'v

Captures prises le 16 septembre 2026 sur le simulateur iPhone 15 Pro et sur l'émulateur Pixel 8, en
mode démo : un bus C12 dont le prochain arrêt est Bellecour A. Poncet, et quatre stations Vélo'v
simulées autour de la place Bellecour (bien fournie, presque vide, vide, fermée). L'ordre des arrêts
de la ligne C12 vient de la vraie fiche horaire servie par le relais ; la course du bus simulé n'y est
pas reconnue, la fiche montre donc le cas « Heure inconnue ».

Même numérotation dans les dossiers `ios/` et `android/` :

| Fichier | Ce qu'on voit |
| --- | --- |
| `01-arret-ou-est-mon-bus` | La fiche d'un arrêt avec, sous les prochains passages de la ligne, « Où est mon bus » : « Arrive, au prochain arrêt », l'heure estimée, et la ligne « Position transmise par TCL il y a 13 s ». Mode démo `arret`. |
| `02-carte-velov` | La carte avec les stations Vélo'v : un carré à la couleur de disponibilité avec le nombre de vélos. Mode démo `velov`. |
| `03-fiche-velov` | La fiche d'une station Vélo'v : vélos et places disponibles, dernière mise à jour, itinéraire à pied. Mode démo `velov-station`. |

Pour reproduire : iOS, lancer l'app avec l'argument `-demo <cas>` ; Android,
`adb shell am start -n com.alertetcl.android/.MainActivity --es demo <cas>`.
