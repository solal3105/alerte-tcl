import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "square.on.square.dashed")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            
                            Text("Configuration des widgets")
                                .font(.headline)
                        }
                        
                        Text("Pour configurer vos widgets :")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Consultez un arrêt ou un parking", systemImage: "1.circle.fill")
                                .font(.caption)
                            Label("Ajoutez le widget à l'écran d'accueil", systemImage: "2.circle.fill")
                                .font(.caption)
                            Label("Appuyez longuement sur le widget", systemImage: "3.circle.fill")
                                .font(.caption)
                            Label("Sélectionnez \"Modifier le widget\"", systemImage: "4.circle.fill")
                                .font(.caption)
                            Label("Choisissez votre arrêt ou parking", systemImage: "5.circle.fill")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Widgets")
                } footer: {
                    Text("Les arrêts et parkings que vous consultez apparaissent automatiquement dans la configuration du widget.")
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://data.grandlyon.com")!) {
                        HStack {
                            Text("Données")
                            Spacer()
                            Text("Grand Lyon")
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("À propos")
                }
            }
            .navigationTitle("Paramètres")
        }
    }
}
