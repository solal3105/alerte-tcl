# Captures d'écran : abonnements et notifications

Captures prises le 15 septembre 2026 sur le simulateur iPhone 15 Pro et sur l'émulateur Pixel 8,
avec des alertes simulées (mode démo) : une perturbation majeure en cours sur C12, une perturbation
sur T1, une information à venir sur C25 et une perturbation majeure sur la ligne 27, à laquelle on
n'est pas abonné. Les abonnements simulés sont C12 (tous les types d'alertes) et T1 (sans les
informations). Rien n'est enregistré sur l'appareil en mode démo. Les couleurs des lignes sont celles du jeu de
données, servies par le relais local le temps des captures (la route `/horaires/` du proxy n'est pas
encore déployée).

Même numérotation dans les dossiers `ios/` et `android/` :

| Fichier | Ce qu'on voit |
| --- | --- |
| `00-carte-bandeau-trafic` | La carte avec le bandeau trafic calculé par la règle partagée : « 1 ligne en alerte majeure ». Mode démo `alertes` (avant l'ouverture de l'écran). |
| `01-alertes-mes-lignes` | L'écran des alertes : résumé, « Mes lignes » avec l'état de chaque ligne abonnée, toutes les lignes. Mode démo `alertes`. |
| `02-fiche-ligne` | La fiche de la ligne C12 : abonné, options, se désabonner, perturbation en cours avec cause et date, information à venir. Mode démo `alertes-ligne`. |
| `03-options-notification` | La feuille « Options de notification » : les trois types d'alertes avec leur description, « Enregistrer » ou « Se désabonner ». Mode démo `alertes-options`. |

Pour reproduire : iOS, lancer l'app avec l'argument `-demo <cas>` ; Android,
`adb shell am start -n com.alertetcl.android/.MainActivity --es demo <cas>`.
