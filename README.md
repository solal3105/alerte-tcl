# 🚇 Alerte TCL

Application iOS minimaliste pour suivre les alertes du réseau de transport TCL (Lyon).

![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-green)

## ✨ Fonctionnalités

- **📋 Liste des lignes** : Métro, Tramway, Funiculaire, Bus
- **🔔 Abonnements** : S'abonner aux lignes qui vous intéressent
- **⚠️ Alertes en temps réel** : Voir les perturbations sur vos lignes
- **📱 Notifications** : Recevoir des alertes push pour vos lignes suivies
- **🎨 Design moderne** : Interface native SwiftUI ultra minimaliste

## 🏗️ Architecture

```
AlerteTCL/
├── AlerteTCLApp.swift          # Point d'entrée
├── Models/
│   ├── Alert.swift             # Modèle d'alerte TCL
│   └── TransportLine.swift     # Modèle de ligne
├── Services/
│   ├── TCLAPIService.swift     # Appels API Grand Lyon
│   ├── NotificationService.swift
│   └── SubscriptionService.swift
├── ViewModels/
│   └── AlertViewModel.swift    # Logique métier
└── Views/
    ├── ContentView.swift       # TabView principal
    ├── AlertsView.swift        # Liste des alertes
    ├── LinesListView.swift     # Liste des lignes
    ├── SubscriptionsView.swift # Abonnements
    └── Components/
        ├── LineRow.swift
        └── AlertCard.swift
```

## 🚀 Guide de démarrage - Première app iOS

### Prérequis

1. **Mac** avec macOS 13+ (Ventura ou plus récent)
2. **Xcode 15+** installé depuis l'App Store
3. **Compte Apple** (gratuit) pour le simulateur
4. *(Optionnel)* Compte Apple Developer (99€/an) pour tester sur un vrai iPhone

### Étape 1 : Installer Xcode

1. Ouvrir l'**App Store** sur ton Mac
2. Rechercher "**Xcode**"
3. Cliquer sur **Obtenir** / **Installer** (≈ 12 Go, prévoir du temps)
4. Une fois installé, **lancer Xcode** une première fois pour qu'il installe les composants

### Étape 2 : Ouvrir le projet

```bash
# Dans le Terminal, naviguer vers le dossier du projet
cd /Users/solal/Documents/codebase/alerte-tcl

# Ouvrir le projet avec Xcode
open AlerteTCL.xcodeproj
```

Ou simplement **double-cliquer** sur `AlerteTCL.xcodeproj` dans le Finder.

### Étape 3 : Configurer le projet

1. Dans Xcode, cliquer sur **AlerteTCL** (icône bleue) dans le panneau de gauche
2. Onglet **Signing & Capabilities**
3. Cocher **"Automatically manage signing"**
4. Sélectionner ton **Team** (ton compte Apple personnel)
   - Si pas de team : Xcode > Settings > Accounts > Ajouter ton Apple ID

### Étape 4 : Lancer sur le simulateur

1. En haut de Xcode, cliquer sur le sélecteur de destination (à côté du bouton ▶️)
2. Choisir un simulateur : **iPhone 15 Pro** (recommandé)
3. Cliquer sur le bouton **▶️ (Run)** ou appuyer sur `Cmd + R`
4. Le simulateur va se lancer avec l'app ! 🎉

### Étape 5 : Tester sur ton iPhone (optionnel)

1. Brancher ton iPhone avec un câble USB
2. **Faire confiance** à l'ordinateur sur l'iPhone si demandé
3. Sélectionner ton iPhone dans le menu des destinations
4. Cliquer sur **▶️ Run**
5. Sur l'iPhone : Réglages > Général > Gestion des appareils > Faire confiance

## 📱 Utilisation de l'app

### Onglet Alertes
- Affiche les alertes **uniquement pour vos lignes suivies**
- Tirez vers le bas pour actualiser
- Tapez sur une alerte pour voir les détails

### Onglet Lignes
- Parcourez toutes les lignes disponibles
- Filtrez par mode de transport (Métro, Tram, Bus...)
- Tapez sur 🔔 pour s'abonner/se désabonner

### Onglet Abonnements
- Voyez toutes vos lignes suivies
- Glissez vers la gauche pour supprimer
- Statistiques en haut (lignes suivies / alertes actives)

## 🔧 Configuration de l'API

L'app utilise l'API ouverte de **Data Grand Lyon** :
- Endpoint : `https://download.data.grandlyon.com/ws/rdata/tcl_sytral.tclalertetrafic_2/all.json`
- Documentation : [data.grandlyon.com](https://data.grandlyon.com)

> **Note** : En cas d'erreur API (authentification requise), l'app affiche des données de démonstration.

## 🎨 Personnalisation

### Changer les couleurs
Modifier `Assets.xcassets/AccentColor.colorset/Contents.json`

### Ajouter des lignes de bus
Éditer `TransportLine.swift` et ajouter dans `allPredefinedLines`

### Modifier la fréquence de refresh
Dans `AlertViewModel.swift`, ajuster la logique de `loadAlerts()`

## 📚 Ressources pour apprendre

- [SwiftUI Tutorials (Apple)](https://developer.apple.com/tutorials/swiftui)
- [Hacking with Swift](https://www.hackingwithswift.com/100/swiftui)
- [Stanford CS193p](https://cs193p.sites.stanford.edu/)

## 🐛 Dépannage

### "Unable to boot simulator"
→ Xcode > Settings > Platforms > Télécharger iOS Simulator

### "Signing requires a development team"
→ Xcode > Settings > Accounts > Ajouter ton Apple ID

### L'API ne répond pas
→ L'app bascule automatiquement sur des données de démo

### Build failed
→ Menu Product > Clean Build Folder (`Cmd + Shift + K`) puis relancer

## 📄 License

MIT - Libre d'utilisation et de modification.

---

**Bonne découverte du développement iOS !** 🚀
