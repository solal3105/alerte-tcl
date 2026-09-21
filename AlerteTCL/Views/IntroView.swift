import SwiftUI
import WidgetKit
import Shared

/// Écran d'intro : une page par nouveauté, illustrée par l'écran correspondant de l'application, avec
/// les textes du module partagé (`Intro`). Il s'ouvre à la première utilisation et après une mise à
/// jour qui change la révision du contenu, et reste consultable depuis l'onglet Info.
struct IntroView: View {
    /// Appelé quand l'intro est terminée ou passée : l'appelant enregistre la révision vue.
    let onFinish: () -> Void

    @State private var position: Int?
    private let pages: [IntroPage] = Intro.shared.pages(includeWidgets: true)

    private var index: Int { position ?? 0 }
    private var isLast: Bool { index >= pages.count - 1 }

    var body: some View {
        ZStack {
            IntroBackground(page: index)
            VStack(spacing: 0) {
                skipButton
                pager
                progress
                nextButton
            }
        }
    }

    // MARK: Les pages

    private var pager: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { slot, page in
                        IntroPageView(page: page, isCurrent: slot == index)
                            .frame(width: geometry.size.width)
                            .id(slot)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
            .scrollIndicators(.hidden)
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
        .padding(.top, 10)
    }

    // MARK: Avancement

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { slot in
                Capsule()
                    .fill(Color.appAccent.opacity(slot == index ? 1 : 0.2))
                    .frame(width: slot == index ? 22 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
        .padding(.bottom, 24)
        .accessibilityLabel("Page \(index + 1) sur \(pages.count)")
    }

    // MARK: Bouton principal

    private var nextButton: some View {
        Button {
            if isLast {
                onFinish()
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { position = index + 1 }
            }
        } label: {
            Text(Intro.shared.buttonTitle(pageIndex: Int32(index), pageCount: Int32(pages.count)))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.appAccent.opacity(0.35), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 28)
        .padding(.bottom, 34)
        .frame(maxWidth: 460)
    }
}

// MARK: - Une page

/// L'illustration en haut, le titre et le texte en dessous. L'illustration glisse moins vite que la
/// page pendant le balayage, et tout le contenu arrive en cascade quand la page passe devant.
private struct IntroPageView: View {
    let page: IntroPage
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 26) {
            IntroVisualView(page: page)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .visualEffect { content, proxy in
                    content.offset(x: proxy.frame(in: .scrollView(axis: .horizontal)).minX * 0.35)
                }
                .opacity(isCurrent ? 1 : 0.35)
                .animation(.easeOut(duration: 0.35), value: isCurrent)

            VStack(spacing: 12) {
                if page.visual == .app {
                    Text(Intro.shared.VERSION_LABEL)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appAccent.opacity(0.14), in: Capsule())
                }
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .offset(y: isCurrent ? 0 : 16)
                    .opacity(isCurrent ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05), value: isCurrent)
                Text(page.body)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: isCurrent ? 0 : 20)
                    .opacity(isCurrent ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.1), value: isCurrent)
            }
            .frame(maxWidth: 380)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 18)
    }
}

// MARK: - Les illustrations

/// Selon la page : l'icône de l'application, une capture de l'écran concerné, les vrais widgets ou la
/// liste des corrections.
private struct IntroVisualView: View {
    let page: IntroPage

    var body: some View {
        switch page.visual {
        case .app: appIcon
        case .widgets: widgets
        case .fixes: fixes
        default: screenshot
        }
    }

    // L'icône de l'application, posée sur son halo.

    private var appIcon: some View {
        AppIconView(size: 148)
            .shadow(color: Color.appAccent.opacity(0.35), radius: 34, x: 0, y: 18)
            .frame(maxHeight: .infinity)
    }

    // Une capture d'écran de l'application, cadrée sur le haut de l'écran.

    private var screenshot: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: 300, maxHeight: .infinity, alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 28, x: 0, y: 16)
            .accessibilityHidden(true)
    }

    private var imageName: String {
        switch page.visual {
        case .stop: return "IntroArret"
        case .timetable: return "IntroHoraires"
        case .map: return "IntroCarte"
        case .city: return "IntroAutour"
        case .velov: return "IntroVelov"
        default: return "IntroAlertes"
        }
    }

    // Trois vrais widgets, rendus avec les vues de l'extension et ses exemples.

    private var widgets: some View {
        GeometryReader { geometry in
            let scale = min(1, geometry.size.width / 338, geometry.size.height / 334)
            VStack(spacing: 16) {
                WidgetPreview(kind: .departures, family: .systemMedium)
                HStack(spacing: 16) {
                    WidgetPreview(kind: .traffic, family: .systemSmall)
                    WidgetPreview(kind: .velov, family: .systemSmall)
                }
            }
            .scaleEffect(scale)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 12)
        }
    }

    // Les corrections : une coche par exemple, sur une carte de verre.

    private var fixes: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(page.points, id: \.self) { point in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.appSuccess)
                    Text(point)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: 340)
        .glassSurface(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Fond

/// Deux halos à l'accent qui dérivent lentement et se replacent à chaque page.
private struct IntroBackground: View {
    let page: Int
    @State private var drift = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
            halo(size: 360, opacity: 0.32)
                .offset(x: drift ? 100 : -80, y: drift ? -260 : -190)
                .offset(x: page.isMultiple(of: 2) ? -30 : 40)
            halo(size: 300, opacity: 0.20)
                .offset(x: drift ? -120 : 90, y: drift ? 260 : 190)
                .offset(x: page.isMultiple(of: 2) ? 30 : -40)
        }
        .animation(.easeInOut(duration: 0.8), value: page)
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
            .blur(radius: 80)
    }
}
