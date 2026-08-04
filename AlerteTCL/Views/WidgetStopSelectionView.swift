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
    let terminusName: String
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
                                    terminusName: item.terminusName,
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
        let selection = WidgetStopSelection(stopId: selected.stopId, stopName: stopName, line: selected.line, direction: selected.direction, terminusName: selected.terminusName)
        widgetStorage.addSelection(selection)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showConfirmation = true }
        feedbackTrigger.toggle()
    }
}

// MARK: - Line Direction Row

struct LineDirectionRow: View {
    let line: String
    let direction: String
    let terminusName: String
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
                    Text(terminusName.isEmpty ? "—" : terminusName)
                        .font(.subheadline).fontWeight(.medium).lineLimit(1)
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

// MARK: - Saved Widget Stops View

