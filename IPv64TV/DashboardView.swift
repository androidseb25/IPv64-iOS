import SwiftUI
import Charts
import IPv64

struct DashboardView: View {
    @Environment(TVSession.self) private var session
    @State private var range = Node64.DNS64Range.last24Hours
    @State private var status: Node64.DNS64Blocking?
    @State private var totals: Node64.DNS64SummaryTotals?
    @State private var buckets: [Node64.DNS64TimelineBucket] = []
    /// Bar width from the node (1 h: 2 min, 24 h: 30 min, 7 d: 4 h).
    @State private var stepMs = 1_800_000
    @State private var rows: [Node64.DNS64LogRow] = []
    @State private var errors: [String: String] = [:]
    @State private var loaded = false
    @State private var writing = false
    @State private var writeError: String?
    /// Bumped by every pause/resume; a refresh started before it must not overwrite the new state.
    @State private var writes = 0
    /// Bumped when the pause countdown ends so the task reloads and the state flips back.
    @State private var expiredTick = 0
    private enum Field { case filter, range }
    /// Locks the range picker while the dashboard has no focus, but only after launch: locked from the first frame,
    /// tvOS would start on the filter menu instead of the tab bar.
    @State private var gatePicker = false
    @FocusState private var focus: Field?
    @AppStorage(TVSettings.keepAwake) private var keepAwake = true
    @AppStorage(TVSettings.streamingMode) private var streaming = false

    private struct LoadKey: Equatable { let range: Node64.DNS64Range; let generation: Int; let tick: Int }

    private var paused: Bool { status?.paused == true }

    var body: some View {
        // Anchored to the top, below the floating tab bar; chart and card share the remaining height.
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label(TVNode.name.map { Streaming.name($0, streaming: streaming) } ?? "Node64", systemImage: "server.rack").font(.largeTitle.bold()).lineLimit(1)
                Spacer(minLength: 0)
                if errors["status"] != nil {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)  // filter state unknown
                }
                blockingButton
                Picker("Range", selection: $range) {
                    Text("1 h").tag(Node64.DNS64Range.lastHour)
                    Text("24 h").tag(Node64.DNS64Range.last24Hours)
                    Text("7 d").tag(Node64.DNS64Range.last7Days)
                }
                .pickerStyle(.segmented)
                .frame(width: 420)
                // Coming down from the tab bar tvOS picks the range picker, and a Menu ignores defaultFocus:
                // while nothing in the dashboard has focus, only the filter menu can take it.
                .disabled(gatePicker && focus == nil)
                .focused($focus, equals: .range)
            }
            tiles.fixedSize(horizontal: false, vertical: true)  // never shrink the numbers; chart and card take the rest
            HStack(alignment: .top, spacing: 50) {
                chart
                recentQueries.frame(width: 700)
            }
        }
        .tvPage()
        .focusSection()
        // .userInitiated: also when the user moves down from the tab bar, not only on first appearance.
        .defaultFocus($focus, .filter, priority: .userInitiated)
        .task {
            try? await Task.sleep(for: .seconds(1))  // the launch focus has settled on the tab bar by then
            gatePicker = true
        }
        .overlay { if !loaded { ProgressView() } }
        .alert("Error", isPresented: Binding(get: { writeError != nil }, set: { if !$0 { writeError = nil } })) {
            Button("OK") {}
        } message: { Text(writeError ?? "") }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepAwake }
        .onChange(of: keepAwake) { UIApplication.shared.isIdleTimerDisabled = keepAwake }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: session.activeId) {
            // Another node: never show the previous node's numbers while the new one loads.
            (totals, buckets, rows, status, errors, loaded) = (nil, [], [], nil, [:], false)
        }
        .task(id: LoadKey(range: range, generation: session.generation, tick: expiredTick)) {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    // MARK: Blocking

    private var blockingButton: some View {
        // System dropdown: the pause durations, or Resume while paused.
        Menu {
            if paused {
                Button("Resume filtering", systemImage: "play.fill") { write { try await $0.resume() } }
            } else {
                Section("Pause filtering") {
                    Button("5 minutes") { write { try await $0.pause(minutes: 5) } }
                    Button("15 minutes") { write { try await $0.pause(minutes: 15) } }
                    Button("30 minutes") { write { try await $0.pause(minutes: 30) } }
                    Button("1 hour") { write { try await $0.pause(minutes: 60) } }
                    Button("Until resumed") { write { try await $0.pause(minutes: 0) } }
                }
            }
        } label: {
            // Ticks every second for the pause countdown.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = paused && status?.untilResumed != true ? status?.pausedUntil?.timeIntervalSince(context.date) : nil
                Label(blockingTitle(remaining), systemImage: paused ? "pause.circle.fill" : "shield.fill")
                    .font(.callout.bold())
                    // Darker shades on the bright focused glass, so the text stays readable.
                    .foregroundStyle(focus == .filter
                                     ? (paused ? Color(red: 0.75, green: 0.1, blue: 0.1) : Color(red: 0.1, green: 0.5, blue: 0.2))
                                     : (paused ? Color.red : Color.green))
                    .onChange(of: remaining.map { $0 <= 0 } ?? false) { _, ended in if ended { expiredTick += 1 } }
            }
        }
        .focused($focus, equals: .filter)
        .modifier(GlassButtonStyle())
        .disabled(writing)
    }

    private func blockingTitle(_ remaining: TimeInterval?) -> String {
        guard paused else { return String(localized: "Filter on") }
        guard let remaining else { return String(localized: "Filter off") }
        let t = max(0, Int(remaining.rounded(.up)))
        let time = t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%02d:%02d", t / 60, t % 60)
        return String(localized: "Filter off · \(time)")
    }

    private func write(_ action: @escaping (Node64.DNS64) async throws -> Node64.DNS64Blocking) {
        guard let dns = session.client?.dns64 else { return }
        writing = true
        writes += 1
        Task {
            defer { writing = false }
            do { status = try await action(dns) } catch { writeError = Streaming.errorText(error, streaming: streaming) }
        }
    }

    // MARK: Tiles and chart

    private var tiles: some View {
        let total = totals?.total ?? 0
        func percent(_ n: Int?) -> String {
            total > 0 ? "\((Double(n ?? 0) / Double(total) * 100).formatted(.number.precision(.fractionLength(1)))) %" : "–"
        }
        return HStack(spacing: 24) {
            tile("Queries", totals?.total, totals?.avgUpstreamMs.map { "Ø \($0.formatted(.number.precision(.fractionLength(0)))) ms" }, "globe", .ipv64)
            tile("Blocked", totals?.blocked, percent(totals?.blocked), "hand.raised.fill", .red.opacity(0.75))
            tile("Cached", totals?.cached, percent(totals?.cached), "bolt.fill", .ipv64)
            tile("Clients", totals?.clients, nil, "person.2.fill", .ipv64)
        }
        .overlay { if let e = errors["summary"] { Text(e).font(.caption).padding(8).background(.red, in: Capsule()) } }
    }

    private func tile(_ title: LocalizedStringKey, _ value: Int?, _ subtitle: String?, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(color)
            Text(value.map { $0.formatted() } ?? "–").font(.system(size: 48, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1)
            Text(subtitle ?? " ").font(.subheadline)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var allowedName: String { String(localized: "Allowed") }
    private var blockedName: String { String(localized: "Blocked") }

    @ViewBuilder private var chart: some View {
        if let e = errors["timeline"] {
            Text(e).foregroundStyle(.red)
        } else {
            // Bars span the bucket (stepMs from the node, minus a small gap); Blocked is stacked on Allowed.
            let width = Double(stepMs) / 1000 * 0.8
            Chart {
                ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in bars(bucket, width: width) }
            }
            .chartForegroundStyleScale([allowedName: Color.green, blockedName: Color.red])
            .chartLegend(position: .bottom)
            .frame(minHeight: 200, maxHeight: .infinity)
        }
    }

    @ChartContentBuilder
    private func bars(_ bucket: Node64.DNS64TimelineBucket, width: TimeInterval) -> some ChartContent {
        if let date = bucket.date {
            let blocked = bucket.blocked ?? 0
            let allowed = max(0, (bucket.total ?? 0) - blocked)
            let end = date.addingTimeInterval(width)
            RectangleMark(xStart: .value("Time", date), xEnd: .value("End", end),
                          yStart: .value("Queries", 0), yEnd: .value("Queries", allowed))
                .foregroundStyle(by: .value("Series", allowedName))
            RectangleMark(xStart: .value("Time", date), xEnd: .value("End", end),
                          yStart: .value("Queries", allowed), yEnd: .value("Queries", allowed + blocked))
                .foregroundStyle(by: .value("Series", blockedName))
        }
    }

    // MARK: Recent queries

    private var recentQueries: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent queries").font(.title3.bold())
            if let e = errors["log"] {
                Text(e).foregroundStyle(.red)
            } else if rows.isEmpty {
                Text("Waiting for queries…").foregroundStyle(.secondary)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in TVLogRow(row: row) }
            Spacer(minLength: 0)
        }
        .padding(30)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .glassCard()
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    // MARK: Loading

    private func refresh() async {
        guard let dns = session.client?.dns64 else { return }
        let writesAtStart = writes
        async let s = catching { try await dns.summary(range: range) }
        async let t = catching { try await dns.timeline(range: range) }
        async let st = catching { try await dns.status() }
        async let l = catching { try await dns.log(limit: 5) }  // what fits the card on a 1080p canvas
        let (sr, tr, str, lr) = await (s, t, st, l)
        if Task.isCancelled { return }
        func apply<T>(_ key: String, _ r: Result<T, Error>, _ set: (T) -> Void) {
            switch r {
            case .success(let v): set(v); errors[key] = nil
            case .failure(let e): errors[key] = Streaming.errorText(e, streaming: streaming)
            }
        }
        apply("summary", sr) { totals = $0.summary }
        apply("timeline", tr) {
            buckets = $0.buckets ?? []
            stepMs = $0.stepMs ?? stepMs
        }
        if writesAtStart == writes { apply("status", str) { status = $0.blocking } }
        apply("log", lr) { rows = $0.rows ?? [] }
        loaded = true
    }
}

/// Liquid Glass on tvOS 26+, regular material before.
private extension View {
    @ViewBuilder func glassCard() -> some View {
        if #available(tvOS 26.0, *) {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        }
    }
}

private struct GlassButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(tvOS 26.0, *) { content.buttonStyle(.glass) } else { content }
    }
}

/// `Result` of an async call. The async `Result { … }` initializer only exists in newer Swift standard
/// libraries (Xcode 27); this keeps the app building with older toolchains (CI runner).
private func catching<T>(_ body: () async throws -> T) async -> Result<T, any Error> {
    do { return .success(try await body()) } catch { return .failure(error) }
}
