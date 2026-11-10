import SwiftUI
import Charts
import IPv64

/// "Queries over time": stacked Allowed/Blocked bars with tap/drag selection (spec 03 §6.4).
struct NodeDnsChartSection: View {
    let timeline: DnsSec<Node64.DNS64Timeline>
    let range: DnsRange

    @State private var selected: Int?

    var body: some View {
        Section("Queries over time") {
            switch timeline {
            case .failure(let failure):
                Text(verbatim: failure.text).foregroundStyle(Color.ipv64Red)
            case .success(let value):
                let bars = dns64Bars((value.buckets ?? []).map { ($0.t, $0.total, $0.blocked) })
                if bars.isEmpty {
                    Text("No data").font(.footnote).foregroundStyle(.secondary)
                } else {
                    chart(bars)
                }
            }
        }
    }

    private func axisLabel(_ bar: Dns64Bar) -> String {
        guard let start = bar.start else { return "" }
        return dns64Format(start, range == .week ? .dayMonth : .hm)
    }

    private func header(_ bars: [Dns64Bar]) -> Text {
        guard let i = selected, bars.indices.contains(i) else { return Text("Tap a bar for details") }
        let bar = bars[i]
        let when = bar.start.map { dns64Format($0, .dayMonthHm) } ?? ""
        return Text("\(when)  Allowed: \(Formatters.count(bar.allowed))  Blocked: \(Formatters.count(bar.blocked))")
    }

    private func chart(_ bars: [Dns64Bar]) -> some View {
        let maxValue = dns64MaxBar(bars)
        return VStack(alignment: .leading, spacing: 8) {
            header(bars).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            Chart {
                ForEach(bars) { bar in
                    BarMark(x: .value("Time", bar.index), y: .value("Queries", bar.allowed), width: .ratio(0.8))
                        .foregroundStyle(by: .value("Type", "Allowed"))
                        .opacity(opacity(bar))
                    BarMark(x: .value("Time", bar.index), y: .value("Queries", bar.blocked), width: .ratio(0.8))
                        .foregroundStyle(by: .value("Type", "Blocked"))
                        .opacity(opacity(bar))
                }
            }
            .chartForegroundStyleScale(["Allowed": Color.ipv64Green, "Blocked": Color.ipv64Red])
            .chartLegend(.hidden)
            .chartXScale(domain: -0.5...(Double(bars.count) - 0.5))
            .chartYScale(domain: 0...maxValue)
            .chartXSelection(value: $selected)
            .chartXAxis {
                AxisMarks(values: dns64AxisIndices(count: bars.count)) { value in
                    AxisValueLabel {
                        if let i = value.as(Int.self), bars.indices.contains(i) { Text(verbatim: axisLabel(bars[i])) }
                    }
                }
            }
            .chartYAxis { AxisMarks(values: [0, maxValue / 2, maxValue]) { AxisGridLine() } }
            .frame(height: 140)
            .accessibilityLabel("Stacked bar chart with \(bars.count) bars, maximum \(Formatters.count(maxValue))")
            HStack(spacing: 12) {
                legend("Allowed", .ipv64Green)
                legend("Blocked", .ipv64Red)
                Spacer()
                Text("max \(Formatters.count(maxValue))")
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .onChange(of: bars) { selected = nil }
    }

    private func opacity(_ bar: Dns64Bar) -> Double { selected == nil || selected == bar.index ? 1 : 0.4 }

    private func legend(_ text: LocalizedStringKey, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}
