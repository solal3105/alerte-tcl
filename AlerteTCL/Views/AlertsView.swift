import SwiftUI

// MARK: - NewAlertsView (Main View)
struct NewAlertsView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    @State private var selectedLine: TransportLine?
    @State private var showSubscribeSheet = false
    @State private var selectedModeFilter: TransportMode? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Global status banner
                if !viewModel.subscribedLines.isEmpty {
                    statusSummaryBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                myLinesSection
                    .padding(.top, 24)

                // Divider
                Rectangle()
                    .fill(Color(.separator).opacity(0.5))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 32)

                allLinesSectionHeader
                    .padding(.top, 24)

                modeFilterTabs
                    .padding(.top, 14)

                linesGrid
                    .padding(.top, 14)
                    .padding(.bottom, 40)
            }
        }
        .refreshable {
            await viewModel.loadAlerts()
        }
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Mise à jour…")
                            .font(.subheadline)
                    }
                    .padding(24)
                    .background(.thickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .sheet(item: $selectedLine) { line in
            LineDetailSheet(line: line, viewModel: viewModel)
        }
        .sheet(isPresented: $showSubscribeSheet) {
            SubscribeLineSheet(viewModel: viewModel)
        }
    }
    
    // MARK: - Status Summary Banner

    private var statusSummaryBanner: some View {
        let totalAlerts = viewModel.subscribedLines.reduce(0) {
            $0 + viewModel.ongoingAlerts(for: $1).count
        }
        let hasMajor = viewModel.subscribedLines.contains {
            viewModel.ongoingAlerts(for: $0).contains { $0.severity == .major }
        }
        let bannerColor: Color = hasMajor ? .red : (totalAlerts > 0 ? .orange : .green)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(bannerColor)
                    .frame(width: 38, height: 38)
                Image(
                    systemName: hasMajor
                        ? "exclamationmark.triangle.fill"
                        : (totalAlerts > 0 ? "bell.badge.fill" : "checkmark")
                )
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, isActive: hasMajor)
            }

            VStack(alignment: .leading, spacing: 2) {
                if totalAlerts == 0 {
                    Text("Toutes vos lignes sont normales")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    Text(
                        "\(totalAlerts) perturbation\(totalAlerts > 1 ? "s" : "") sur vos lignes"
                    )
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
                if let last = viewModel.lastUpdate {
                    Text("Mis à jour \(last, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(bannerColor.opacity(0.1))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(bannerColor.opacity(0.25), lineWidth: 1)
        }
    }

    // MARK: - My Lines Section

    private var myLinesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mes lignes")
                        .font(.title2)
                        .fontWeight(.bold)
                    if !viewModel.subscribedLines.isEmpty {
                        Text(
                            "\(viewModel.subscribedLines.count) abonnement\(viewModel.subscribedLines.count > 1 ? "s" : "")"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    showSubscribeSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.blue)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)

            if viewModel.subscribedLines.isEmpty {
                emptySubscriptionsView
            } else {
                TabView {
                    ForEach(sortedSubscribedLines) { line in
                        LineStatusCard(
                            line: line,
                            alerts: viewModel.ongoingAlerts(for: line),
                            highestSeverity: highestSeverity(for: line)
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .onTapGesture {
                            selectedLine = line
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 152)
            }
        }
    }
    
    private var sortedSubscribedLines: [TransportLine] {
        viewModel.subscribedLines.sorted { l1, l2 in
            let s1 = highestSeverity(for: l1)?.sortOrder ?? 999
            let s2 = highestSeverity(for: l2)?.sortOrder ?? 999
            if s1 != s2 { return s1 < s2 }
            if l1.mode.sortOrder != l2.mode.sortOrder {
                return l1.mode.sortOrder < l2.mode.sortOrder
            }
            return l1.displayName.localizedStandardCompare(l2.displayName) == .orderedAscending
        }
    }

    private func highestSeverity(for line: TransportLine) -> AlertSeverity? {
        viewModel.ongoingAlerts(for: line)
            .map { $0.severity }
            .min { $0.sortOrder < $1.sortOrder }
    }
    
    private var emptySubscriptionsView: some View {
        Button {
            showSubscribeSheet = true
        } label: {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 72, height: 72)
                    Image(systemName: "bell.badge")
                        .font(.system(size: 30))
                        .foregroundStyle(.blue)
                }

                VStack(spacing: 6) {
                    Text("Suivez vos lignes")
                        .font(.headline)
                    Text(
                        "Recevez des alertes en temps réel pour les lignes qui vous importent"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }

                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("S'abonner à une ligne")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 24)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
    
    // MARK: - All Lines Section

    private var allLinesSectionHeader: some View {
        HStack {
            Text("Toutes les lignes")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var modeFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ModeFilterChip(
                    label: "Tout",
                    icon: "square.grid.2x2.fill",
                    color: .secondary,
                    isSelected: selectedModeFilter == nil
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedModeFilter = nil
                    }
                }
                ForEach(
                    TransportMode.allCases.sorted { $0.sortOrder < $1.sortOrder },
                    id: \.self
                ) { mode in
                    if viewModel.allLines.contains(where: { $0.mode == mode }) {
                        ModeFilterChip(
                            label: mode.rawValue,
                            icon: mode.icon,
                            color: mode.color,
                            isSelected: selectedModeFilter == mode
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedModeFilter = mode
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var filteredLinesForGrid: [TransportLine] {
        let base: [TransportLine]
        if let mode = selectedModeFilter {
            base = viewModel.allLines.filter { $0.mode == mode }
        } else {
            base = viewModel.allLines
        }
        return base.sorted {
            if $0.mode.sortOrder != $1.mode.sortOrder {
                return $0.mode.sortOrder < $1.mode.sortOrder
            }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private var linesGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ],
            spacing: 10
        ) {
            ForEach(filteredLinesForGrid) { line in
                LineGridCell(
                    line: line,
                    alertCount: viewModel.alertCount(for: line),
                    isSubscribed: viewModel.isSubscribed(to: line)
                )
                .onTapGesture {
                    selectedLine = line
                }
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.4), value: selectedModeFilter)
    }
}

// MARK: - Mode Filter Chip

private struct ModeFilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color(.systemBackground) : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Line Status Card (subscribed lines carousel)

private struct LineStatusCard: View {
    let line: TransportLine
    let alerts: [TCLAlert]
    let highestSeverity: AlertSeverity?

    @State private var isPulsing = false

    private var isMajor: Bool { highestSeverity == .major }

    private var statusColor: Color {
        guard let sev = highestSeverity else { return .green }
        switch sev {
        case .major: return .red
        case .disruption: return .orange
        case .info: return .blue
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor)
                .frame(width: 5)

            HStack(spacing: 16) {
                AlertLineBadgeView(line: line, size: 62)
                    .shadow(color: line.mode.color.opacity(0.35), radius: 10, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(line.mode.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(line.mode.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(line.mode.color.opacity(0.12))
                        .clipShape(Capsule())

                    Text("Ligne \(line.displayName)")
                        .font(.title3)
                        .fontWeight(.bold)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                            .scaleEffect(isPulsing && isMajor ? 1.5 : 1.0)
                            .animation(
                                isMajor
                                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                    : .default,
                                value: isPulsing
                            )

                        if alerts.isEmpty {
                            Text("Service normal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(
                                "\(alerts.count) perturbation\(alerts.count > 1 ? "s" : "")"
                            )
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(statusColor)
                        }
                    }
                }

                Spacer(minLength: 0)

                if !alerts.isEmpty {
                    VStack(spacing: 2) {
                        Text("\(alerts.count)")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(statusColor)
                        Text(alerts.count > 1 ? "alertes" : "alerte")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(statusColor.opacity(0.65))
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                }
            }
            .padding(16)
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.background)
                .shadow(color: statusColor.opacity(0.18), radius: 18, x: 0, y: 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(statusColor.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            if isMajor { isPulsing = true }
        }
    }
}

// MARK: - Line Grid Cell (3-column grid)

private struct LineGridCell: View {
    let line: TransportLine
    let alertCount: Int
    let isSubscribed: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                AlertLineBadgeView(line: line, size: 50)
                Text(line.displayName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(line.mode.color.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        line.mode.color.opacity(isSubscribed ? 0.45 : 0.15),
                        lineWidth: isSubscribed ? 1.5 : 0.5
                    )
            }

            if alertCount > 0 {
                Text("\(alertCount)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .padding(.horizontal, 4)
                    .background(.red)
                    .clipShape(Capsule())
                    .offset(x: 4, y: -4)
            } else if isSubscribed {
                Image(systemName: "bell.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(.blue)
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }
}

// MARK: - Line Detail Sheet
struct LineDetailSheet: View {
    let line: TransportLine
    @ObservedObject var viewModel: AlertViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSubscriptionOptions = false
    
    private var lineAlerts: [TCLAlert] {
        viewModel.ongoingAlerts(for: line).sorted { $0.severity.sortOrder < $1.severity.sortOrder }
    }
    
    private var upcomingAlerts: [TCLAlert] {
        viewModel.upcomingAlerts(for: line).sorted { a, b in
            (a.debut ?? .distantFuture) < (b.debut ?? .distantFuture)
        }
    }
    
    private var isSubscribed: Bool {
        viewModel.isSubscribed(to: line)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader

                    VStack(spacing: 20) {
                        subscribeSection
                            .padding(.horizontal, 16)

                        if lineAlerts.isEmpty && upcomingAlerts.isEmpty {
                            noAlertsView
                        } else {
                            if !lineAlerts.isEmpty { alertsSection }
                            if !upcomingAlerts.isEmpty { upcomingAlertsSection }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle("Ligne \(line.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showSubscriptionOptions) {
                SubscriptionOptionsSheet(line: line, viewModel: viewModel)
            }
        }
        .interactiveDismissDisabled(false)
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    line.mode.color.opacity(0.85),
                    line.mode.color.opacity(0.45),
                    line.mode.color.opacity(0.15),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            .frame(width: 160, height: 160)
                            .offset(x: geo.size.width - 60, y: -40)
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            .frame(width: 250, height: 250)
                            .offset(x: geo.size.width - 80, y: -100)
                    }
                }
            }

            HStack(spacing: 18) {
                AlertLineBadgeView(line: line, size: 76)
                    .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(line.mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.8))

                    Text("Ligne \(line.displayName)")
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundStyle(.white)

                    heroStatusPill
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var heroStatusPill: some View {
        let isClear = lineAlerts.isEmpty
        return HStack(spacing: 5) {
            Image(
                systemName: isClear
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill"
            )
            .font(.caption)
            Text(
                isClear
                    ? "Service normal"
                    : "\(lineAlerts.count) perturbation\(lineAlerts.count > 1 ? "s" : "")"
            )
            .font(.caption)
            .fontWeight(.semibold)
        }
        .foregroundStyle(isClear ? .green : .orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.black.opacity(0.22))
        .clipShape(Capsule())
    }
    
    private var subscribeSection: some View {
        Group {
            if isSubscribed {
                HStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: "bell.fill")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        Text("Abonné")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())

                    Spacer()

                    Button {
                        showSubscriptionOptions = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Options")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .controlSize(.small)

                    Button {
                        withAnimation { viewModel.toggleSubscription(for: line) }
                    } label: {
                        Image(systemName: "bell.slash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                }
            } else {
                Button {
                    showSubscriptionOptions = true
                } label: {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                        Text("S'abonner à cette ligne")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
            }
        }
    }
    
    private var noAlertsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
                .symbolEffect(.pulse)

            Text("Service normal")
                .font(.title3)
                .fontWeight(.bold)

            Text("Aucune perturbation en cours sur cette ligne")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("En cours", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(lineAlerts) { alert in
                    AlertDetailCard(alert: alert)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var upcomingAlertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("À venir", systemImage: "calendar.badge.clock")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(upcomingAlerts) { alert in
                    AlertDetailCard(alert: alert, isUpcoming: true)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Alert Detail Card
private struct AlertDetailCard: View {
    let alert: TCLAlert
    var isUpcoming: Bool = false
    @State private var isExpanded = false

    private var accentColor: Color {
        if isUpcoming { return .secondary }
        switch alert.severity {
        case .major: return .red
        case .disruption: return .orange
        case .info: return .blue
        }
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(
                            systemName: isUpcoming
                                ? "calendar.badge.clock"
                                : alert.severity.icon
                        )
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentColor)

                        Text(isUpcoming ? "À venir" : alert.severity.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(accentColor)

                        if !alert.cause.isEmpty {
                            Text("·")
                                .foregroundStyle(.quaternary)
                            Text(alert.cause)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        if let debut = alert.debut {
                            Text(smartDateLabel(debut))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Text(alert.titre)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if isExpanded {
                        if !alert.message.isEmpty {
                            Text(alert.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        if let fin = alert.fin {
                            Label(
                                "Jusqu'au \(fin.formatted(date: .abbreviated, time: .shortened))",
                                systemImage: "clock"
                            )
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    HStack {
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                }
                .padding(14)
            }
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accentColor.opacity(isExpanded ? 0.07 : 0.04))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.22), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func smartDateLabel(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "Il y a \(Int(diff / 60)) min" }
        if diff < 86400 { return date.formatted(date: .omitted, time: .shortened) }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Subscription Options Sheet
struct SubscriptionOptionsSheet: View {
    let line: TransportLine
    @ObservedObject var viewModel: AlertViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTypes: Set<AlertSeverity>
    
    init(line: TransportLine, viewModel: AlertViewModel) {
        self.line = line
        self.viewModel = viewModel
        let currentPrefs = viewModel.subscriptionService.getNotificationPreferences(for: line)
        _selectedTypes = State(initialValue: currentPrefs)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    AlertLineBadgeView(line: line, size: 72)
                    
                    Text("Notifications pour la ligne \(line.displayName)")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Choisissez les types d'alertes que vous souhaitez recevoir")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Options
                VStack(spacing: 12) {
                    ForEach(AlertSeverity.allCases) { severity in
                        NotificationTypeRow(
                            severity: severity,
                            isSelected: selectedTypes.contains(severity)
                        ) {
                            if selectedTypes.contains(severity) {
                                selectedTypes.remove(severity)
                            } else {
                                selectedTypes.insert(severity)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Save button
                Button {
                    if selectedTypes.isEmpty {
                        viewModel.subscriptionService.unsubscribe(from: line)
                    } else if viewModel.isSubscribed(to: line) {
                        viewModel.subscriptionService.updateNotificationPreferences(for: line, types: selectedTypes)
                    } else {
                        viewModel.subscriptionService.subscribe(to: line, notificationTypes: selectedTypes)
                    }
                    dismiss()
                } label: {
                    Text(selectedTypes.isEmpty ? "Se désabonner" : "Enregistrer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedTypes.isEmpty ? .red : .blue)
                .controlSize(.large)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle("Options de notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Notification Type Row
private struct NotificationTypeRow: View {
    let severity: AlertSeverity
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(severityColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: severity.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(severityColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(severity.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(severityDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? severityColor : .secondary)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var severityColor: Color {
        switch severity {
        case .major: return .red
        case .disruption: return .orange
        case .info: return .blue
        }
    }
    
    private var severityDescription: String {
        switch severity {
        case .major: return "Interruptions totales de service"
        case .disruption: return "Retards et déviations importantes"
        case .info: return "Informations et travaux prévus"
        }
    }
}

// MARK: - Subscribe Line Sheet
struct SubscribeLineSheet: View {
    @ObservedObject var viewModel: AlertViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedLine: TransportLine?
    
    private var filteredLines: [TransportLine] {
        let lines = viewModel.allLines.filter { !viewModel.isSubscribed(to: $0) }
        
        if searchText.isEmpty {
            return lines.sorted { $0.mode.sortOrder < $1.mode.sortOrder }
        }
        
        return lines.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.ligneCom.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.mode.sortOrder < $1.mode.sortOrder }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(TransportMode.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { mode in
                    let modeLines = filteredLines.filter { $0.mode == mode }
                    
                    if !modeLines.isEmpty {
                        Section {
                            ForEach(modeLines) { line in
                                Button {
                                    selectedLine = line
                                } label: {
                                    HStack(spacing: 12) {
                                        AlertLineBadgeView(line: line, size: 40)
                                        
                                        Text("Ligne \(line.displayName)")
                                            .foregroundStyle(.primary)
                                        
                                        Spacer()
                                        
                                        let count = viewModel.alertCount(for: line)
                                        if count > 0 {
                                            Text("\(count) alerte\(count > 1 ? "s" : "")")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                    .foregroundStyle(mode.color)
                                Text(mode.rawValue)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher une ligne")
            .navigationTitle("S'abonner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedLine) { line in
                SubscriptionOptionsSheet(line: line, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Alert Line Badge View (with proper colors per line type)

struct AlertLineBadgeView: View {
    let line: TransportLine
    let size: CGFloat
    
    private var lineName: String {
        line.ligneCli.isEmpty ? line.ligneCom : line.ligneCli
    }
    
    private var bgColor: Color {
        LineColorHelper.backgroundColor(for: lineName)
    }
    
    private var textColor: Color {
        LineColorHelper.textColor(for: lineName)
    }
    
    private var needsBorder: Bool {
        LineColorHelper.needsBorder(for: lineName)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(bgColor)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .stroke(Color(.systemGray3), lineWidth: needsBorder ? 1 : 0)
                )
            
            Text(lineName)
                .font(.system(size: size * 0.28, weight: .black))
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}

// MARK: - Legacy AlertsView (kept for compatibility)
struct AlertsView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    
    var body: some View {
        NewAlertsView()
    }
}

#Preview {
    NewAlertsView()
        .environmentObject(AlertViewModel())
}
