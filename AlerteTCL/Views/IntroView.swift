import SwiftUI
import Shared

/// Écran d'intro : une page par nouveauté, avec les textes du module partagé (`Intro`). Il s'ouvre à
/// la première utilisation et après une mise à jour qui change la révision du contenu, et reste
/// consultable depuis l'onglet Info. Une seule teinte, l'accent.
struct IntroView: View {
    /// Appelé quand l'intro est terminée ou passée : l'appelant enregistre la révision vue.
    let onFinish: () -> Void

    @State private var index = 0
    private let pages: [IntroPage] = Intro.shared.pages(includeWidgets: true)

    private var isLast: Bool { index >= pages.count - 1 }

    var body: some View {
        ZStack {
            IntroBackground()
            VStack(spacing: 0) {
                skipButton
                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { position, page in
                        IntroPageView(page: page, isCurrent: position == index)
                            .tag(position)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                progress
                nextButton
            }
            .frame(maxWidth: 480)
        }
    }

    // MARK: Passer

    private var skipButton: some View {
        HStack {
            Spacer()
            Button("Passer l'intro") { onFinish() }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appAccent)
                .opacity(isLast ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: isLast)
                .accessibilityHidden(isLast)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: Avancement

    private var progress: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { position in
                Capsule()
                    .fill(Color.appAccent.opacity(position == index ? 1 : 0.22))
                    .frame(width: position == index ? 24 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
        .padding(.bottom, 28)
        .accessibilityLabel("Page \(index + 1) sur \(pages.count)")
    }

    // MARK: Bouton principal

    private var nextButton: some View {
        Button {
            if isLast {
                onFinish()
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { index += 1 }
            }
        } label: {
            Text(Intro.shared.buttonTitle(pageIndex: Int32(index), pageCount: Int32(pages.count)))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.appAccent.opacity(0.32), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 28)
        .padding(.bottom, 36)
    }
}

// MARK: - Une page

/// Pictogramme sur disque de verre, titre, texte : les trois arrivent en cascade quand la page passe devant.
private struct IntroPageView: View {
    let page: IntroPage
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            icon
            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .offset(y: isCurrent ? 0 : 14)
                    .opacity(isCurrent ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.06), value: isCurrent)
                Text(page.body)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: isCurrent ? 0 : 18)
                    .opacity(isCurrent ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.12), value: isCurrent)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
    }

    private var icon: some View {
        Image(systemName: symbol(for: page.icon))
            .font(.system(size: 46, weight: .semibold))
            .foregroundStyle(Color.appAccent)
            .frame(width: 116, height: 116)
            .glassSurface(Circle())
            .overlay(Circle().strokeBorder(Color.appAccent.opacity(0.22), lineWidth: 1))
            .shadow(color: Color.appAccent.opacity(0.22), radius: 26, x: 0, y: 14)
            .scaleEffect(isCurrent ? 1 : 0.86)
            .opacity(isCurrent ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: isCurrent)
            .accessibilityHidden(true)
    }

    /// Pictogramme de chaque page ; la page d'ouverture porte le tramway de l'icône de l'application.
    private func symbol(for icon: IntroIcon) -> String {
        switch icon {
        case .busArrival: return "bus.fill"
        case .timetable: return "clock.fill"
        case .map: return "map.fill"
        case .city: return "mappin.and.ellipse"
        case .alerts: return "bell.badge.fill"
        case .widgets: return "square.grid.2x2.fill"
        default: return "tram.fill"
        }
    }
}

// MARK: - Fond

/// Deux halos à l'accent qui dérivent lentement derrière le contenu, sur le fond du système.
private struct IntroBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
            halo(size: 320, opacity: 0.30)
                .offset(x: drift ? 90 : -70, y: drift ? -220 : -140)
            halo(size: 260, opacity: 0.22)
                .offset(x: drift ? -110 : 80, y: drift ? 240 : 170)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    private func halo(size: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(Color.appAccent.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 70)
    }
}
