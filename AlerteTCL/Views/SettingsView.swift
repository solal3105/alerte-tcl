import SwiftUI

struct SettingsView: View {
    @State private var showWidgetHelp = false
    @State private var showSavedStops = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showWidgetHelp = true
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Comment configurer le widget")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Guide étape par étape")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showSavedStops = true
                    } label: {
                        HStack {
                            Image(systemName: "tram.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mes arrêts widget")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Gérer les arrêts sauvegardés")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Widget Prochains Passages")
                } footer: {
                    Text("Ajoutez des arrêts depuis la fiche d'un arrêt sur la carte, puis configurez le widget sur votre écran d'accueil.")
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
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .sheet(isPresented: $showWidgetHelp) {
                WidgetHelpView()
            }
            .sheet(isPresented: $showSavedStops) {
                SavedWidgetStopsView()
            }
        }
    }
}
