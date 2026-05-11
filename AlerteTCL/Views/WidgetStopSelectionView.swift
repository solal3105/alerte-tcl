//
//  WidgetStopSelectionView.swift
//  AlerteTCL
//
//  Interface pour sélectionner un arrêt/ligne à ajouter au widget
//

import SwiftUI
import WidgetKit

// MARK: - Line Direction Item

/// Associe une ligne et une direction au sous-arrêt exact qui les dessert.
/// Évite le bug de stopId incorrect sur les arrêts fusionnés.
struct WidgetLineDirection: Identifiable {
    let stopId: Int
    let line: String
    let direction: String
    var id: String { "\(stopId)-\(line)-\(direction)" }
}

// MARK: - Add to Widget Sheet

struct AddToWidgetSheet: View {
    let stopName: String
    let availableLineDirections: [WidgetLineDirection]
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var widgetStorage = WidgetStopStorage.shared
    @State private var selectedLineDirection: WidgetLineDirection?
    @State private var showConfirmation = false
    @State private var feedbackTrigger = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                
                ScrollView {
                    if availableLineDirections.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 36)).foregroundStyle(.secondary)
                            Text("Impossible de charger les directions.\nVérifiez votre connexion et réessayez.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(availableLineDirections) { item in
                                LineDirectionRow(
                                    line: item.line,
                                    direction: item.direction,
                                    isSelected: selectedLineDirection?.id == item.id,
                                    isAlreadySaved: widgetStorage.hasSelection(stopId: item.stopId, line: item.line, direction: item.direction)
                                ) {
                                    if !widgetStorage.hasSelection(stopId: item.stopId, line: item.line, direction: item.direction) {
                                        selectedLineDirection = item
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
                
                if selectedLineDirection != nil {
                    addButton
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ajouter au widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .overlay {
                if showConfirmation { confirmationOverlay }
            }
            .sensoryFeedback(.success, trigger: feedbackTrigger)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 70, height: 70)
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 8) {
                Text(stopName).font(.title3).fontWeight(.bold)
                Text("Choisissez la ligne et la direction à afficher dans votre widget")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
    
    private var addButton: some View {
        Button { addToWidget() } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill").font(.system(size: 20))
                Text("Ajouter au widget").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .controlSize(.large)
        .padding(20)
    }
    
    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(.green).frame(width: 80, height: 80)
                    Image(systemName: "checkmark").font(.system(size: 36, weight: .bold)).foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Ajouté au widget !").font(.title2).fontWeight(.bold)
                    Text("Maintenez appuyé sur votre écran d'accueil pour ajouter le widget \"Prochains passages\"")
                        .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                
                Button { dismiss() } label: {
                    Text("Compris").fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(32)
        }
        .transition(.opacity)
    }
    
    private func addToWidget() {
        guard let selected = selectedLineDirection else { return }
        let selection = WidgetStopSelection(stopId: selected.stopId, stopName: stopName, line: selected.line, direction: selected.direction)
        widgetStorage.addSelection(selection)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showConfirmation = true }
        feedbackTrigger.toggle()
    }
}

// MARK: - Line Direction Row

struct LineDirectionRow: View {
    let line: String
    let direction: String
    let isSelected: Bool
    let isAlreadySaved: Bool
    let onTap: () -> Void
    
    private var bgColor: Color { LineColorHelper.backgroundColor(for: line) }
    private var textColor: Color { LineColorHelper.textColor(for: line) }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(line)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(textColor)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(bgColor).clipShape(Capsule())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Direction").font(.caption2).foregroundStyle(.secondary)
                    Text(direction).font(.subheadline).fontWeight(.medium).lineLimit(1)
                }
                
                Spacer()
                
                if isAlreadySaved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Ajouté").font(.caption).foregroundStyle(.green)
                    }
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(.blue)
                } else {
                    Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2).frame(width: 24, height: 24)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(isSelected ? bgColor.opacity(0.15) : Color(.systemBackground)))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? bgColor : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(isAlreadySaved)
        .opacity(isAlreadySaved ? 0.6 : 1)
    }
}

// MARK: - Widget Help View

struct WidgetHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    
                    VStack(spacing: 24) {
                        StepCard(number: 1, title: "Depuis l'app", description: "Ouvrez la fiche d'un arrêt en appuyant dessus sur la carte, puis appuyez sur \"Ajouter au widget\"", icon: "hand.tap.fill", color: .blue)
                        StepCard(number: 2, title: "Choisissez votre ligne", description: "Sélectionnez la ligne et la direction que vous voulez suivre", icon: "tram.fill", color: .purple)
                        StepCard(number: 3, title: "Ajoutez le widget", description: "Maintenez appuyé sur votre écran d'accueil, appuyez sur + en haut à gauche, cherchez \"AlerteTCL\"", icon: "apps.iphone", color: .orange)
                        StepCard(number: 4, title: "Configurez", description: "Maintenez appuyé sur le widget et choisissez \"Modifier le widget\" pour sélectionner votre arrêt", icon: "gearshape.fill", color: .green)
                    }
                    .padding(.horizontal, 20)
                    
                    tipSection
                }
                .padding(.vertical, 20)
            }
            .background(.background)
            .navigationTitle("Configurer le widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                
                VStack(spacing: 4) {
                    Text("MA").font(.system(size: 18, weight: .black)).foregroundColor(.white)
                    Text("2'").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Text("14:32").font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
                }
            }
            
            VStack(spacing: 8) {
                Text("Widget Prochains Passages").font(.title2).fontWeight(.bold)
                Text("Voyez en un coup d'œil quand arrive votre prochain transport").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(24)
    }
    
    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Astuce", systemImage: "lightbulb.fill").font(.headline).foregroundColor(.yellow)
            Text("Vous pouvez ajouter plusieurs widgets pour suivre différents arrêts ! Parfait pour votre trajet domicile-travail.")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

struct StepCard: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 50, height: 50)
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("\(number)").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .frame(width: 22, height: 22).background(color).clipShape(Circle())
                    Text(title).font(.headline)
                }
                Text(description).font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Saved Widget Stops View

struct SavedWidgetStopsView: View {
    @ObservedObject private var widgetStorage = WidgetStopStorage.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if widgetStorage.selections.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(widgetStorage.selections) { selection in
                            SavedStopRow(selection: selection)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { widgetStorage.removeSelection(at: $0) }
                        }
                        .onMove { source, destination in
                            widgetStorage.moveSelection(from: source, to: destination)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Mes arrêts widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !widgetStorage.selections.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 50)).foregroundColor(.secondary)
            VStack(spacing: 12) {
                Text("Aucun arrêt sauvegardé").font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Allez sur l'onglet Transport", systemImage: "1.circle.fill")
                    Label("Appuyez sur un arrêt sur la carte", systemImage: "2.circle.fill")
                    Label("Appuyez sur \"Ajouter au widget\"", systemImage: "3.circle.fill")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding(40)
    }
}

struct SavedStopRow: View {
    let selection: WidgetStopSelection
    
    private var bgColor: Color { LineColorHelper.backgroundColor(for: selection.line) }
    private var textColor: Color { LineColorHelper.textColor(for: selection.line) }
    
    var body: some View {
        HStack(spacing: 14) {
            Text(selection.line)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(textColor)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(bgColor).clipShape(Capsule())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(selection.stopName).font(.subheadline).fontWeight(.semibold)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right").font(.system(size: 9))
                    Text(selection.direction).font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
