import SwiftUI

struct ListRow<Trailing: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appInCard) private var inCard

    private let title: Text
    private let subtitle: Text?
    private let systemImage: String?
    private let iconTint: Color
    private let badge: String?
    private let showChevron: Bool
    private let subtitleLineLimit: Int
    private let titleColor: Color
    private let monospacedTitle: Bool
    private let monospacedSubtitle: Bool
    private let trailing: Trailing

    init(
        title: Text, subtitle: Text? = nil, systemImage: String? = nil, iconTint: Color = .secondary,
        badge: String? = nil, showChevron: Bool = false, subtitleLineLimit: Int = 2,
        titleColor: Color = .primary, monospacedTitle: Bool = false, monospacedSubtitle: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.iconTint = iconTint
        self.badge = badge
        self.showChevron = showChevron
        self.subtitleLineLimit = subtitleLineLimit
        self.titleColor = titleColor
        self.monospacedTitle = monospacedTitle
        self.monospacedSubtitle = monospacedSubtitle
        self.trailing = trailing()
    }

    init(
        _ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, systemImage: String? = nil,
        iconTint: Color = .secondary, badge: String? = nil, showChevron: Bool = false,
        subtitleLineLimit: Int = 2, titleColor: Color = .primary, monospacedTitle: Bool = false,
        monospacedSubtitle: Bool = false, @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            title: Text(title), subtitle: subtitle.map { Text($0) }, systemImage: systemImage,
            iconTint: iconTint, badge: badge, showChevron: showChevron, subtitleLineLimit: subtitleLineLimit,
            titleColor: titleColor, monospacedTitle: monospacedTitle, monospacedSubtitle: monospacedSubtitle,
            trailing: trailing)
    }

    init(
        verbatim title: String, subtitle: String? = nil, systemImage: String? = nil,
        iconTint: Color = .secondary, badge: String? = nil, showChevron: Bool = false,
        subtitleLineLimit: Int = 2, titleColor: Color = .primary, monospacedTitle: Bool = false,
        monospacedSubtitle: Bool = false, @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            title: Text(verbatim: title), subtitle: subtitle.map { Text(verbatim: $0) }, systemImage: systemImage,
            iconTint: iconTint, badge: badge, showChevron: showChevron, subtitleLineLimit: subtitleLineLimit,
            titleColor: titleColor, monospacedTitle: monospacedTitle, monospacedSubtitle: monospacedSubtitle,
            trailing: trailing)
    }

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(iconTint)
                    .frame(width: 28)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(monospacedTitle ? .body.monospaced() : .body)
                    .foregroundStyle(titleColor)
                if let subtitle {
                    subtitle
                        .font(monospacedSubtitle ? .subheadline.monospaced() : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(subtitleLineLimit)
                }
            }
            Spacer(minLength: 0)
            trailing
            if let badge {
                Text(verbatim: badge).font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
            }
            if showChevron && inCard {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.38)
    }
}

extension ListRow where Trailing == EmptyView {
    init(
        title: Text, subtitle: Text? = nil, systemImage: String? = nil, iconTint: Color = .secondary,
        badge: String? = nil, showChevron: Bool = false, subtitleLineLimit: Int = 2,
        titleColor: Color = .primary, monospacedTitle: Bool = false, monospacedSubtitle: Bool = false
    ) {
        self.init(
            title: title, subtitle: subtitle, systemImage: systemImage, iconTint: iconTint, badge: badge,
            showChevron: showChevron, subtitleLineLimit: subtitleLineLimit, titleColor: titleColor,
            monospacedTitle: monospacedTitle, monospacedSubtitle: monospacedSubtitle) { EmptyView() }
    }

    init(
        _ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, systemImage: String? = nil,
        iconTint: Color = .secondary, badge: String? = nil, showChevron: Bool = false,
        subtitleLineLimit: Int = 2, titleColor: Color = .primary, monospacedTitle: Bool = false,
        monospacedSubtitle: Bool = false
    ) {
        self.init(
            title: Text(title), subtitle: subtitle.map { Text($0) }, systemImage: systemImage,
            iconTint: iconTint, badge: badge, showChevron: showChevron, subtitleLineLimit: subtitleLineLimit,
            titleColor: titleColor, monospacedTitle: monospacedTitle, monospacedSubtitle: monospacedSubtitle)
    }

    init(
        verbatim title: String, subtitle: String? = nil, systemImage: String? = nil,
        iconTint: Color = .secondary, badge: String? = nil, showChevron: Bool = false,
        subtitleLineLimit: Int = 2, titleColor: Color = .primary, monospacedTitle: Bool = false,
        monospacedSubtitle: Bool = false
    ) {
        self.init(
            title: Text(verbatim: title), subtitle: subtitle.map { Text(verbatim: $0) }, systemImage: systemImage,
            iconTint: iconTint, badge: badge, showChevron: showChevron, subtitleLineLimit: subtitleLineLimit,
            titleColor: titleColor, monospacedTitle: monospacedTitle, monospacedSubtitle: monospacedSubtitle)
    }
}

struct InfoRow: View {
    private let label: LocalizedStringKey
    private let value: String?
    private let copyable: Bool
    private let sensitive: Bool
    private let monospaced: Bool
    private let valueColor: Color?
    @State private var copied = 0

    init(_ label: LocalizedStringKey, value: String?, copyable: Bool = false, sensitive: Bool = false,
         monospaced: Bool = false, valueColor: Color? = nil) {
        self.label = label
        self.value = value
        self.copyable = copyable
        self.sensitive = sensitive
        self.monospaced = monospaced
        self.valueColor = valueColor
    }

    private var raw: String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                if let raw {
                    if sensitive {
                        SensitiveText(raw, monospaced: monospaced)
                    } else {
                        Text(verbatim: raw)
                            .font(monospaced ? .body.monospaced() : .body)
                            .foregroundStyle(valueColor ?? .secondary)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                } else {
                    Text(verbatim: "–").foregroundStyle(valueColor ?? .secondary)
                }
                if copyable, let raw {
                    Button {
                        Clipboard.copy(raw, sensitive: sensitive)
                        copied += 1
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc").labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Copy \(Text(label))"))
                    .sensoryFeedback(.success, trigger: copied)
                }
            }
        } label: {
            Text(label)
        }
    }
}

struct InfoItem: Identifiable {
    let id = UUID()
    var label: LocalizedStringKey
    var value: String?
    var copyable = false
    var sensitive = false
    var monospaced = false
    var valueColor: Color?

    init(_ label: LocalizedStringKey, value: String?, copyable: Bool = false, sensitive: Bool = false,
         monospaced: Bool = false, valueColor: Color? = nil) {
        self.label = label
        self.value = value
        self.copyable = copyable
        self.sensitive = sensitive
        self.monospaced = monospaced
        self.valueColor = valueColor
    }
}

struct InfoGroup: View {
    private let title: LocalizedStringKey?
    private let rows: [InfoItem]

    init(_ title: LocalizedStringKey? = nil, hideEmpty: Bool = false, rows: [InfoItem]) {
        self.title = title
        self.rows = hideEmpty
            ? rows.filter { !($0.value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            : rows
    }

    var body: some View {
        ListGroup(title) {
            ForEach(rows) { row in
                InfoRow(row.label, value: row.value, copyable: row.copyable, sensitive: row.sensitive,
                        monospaced: row.monospaced, valueColor: row.valueColor)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ListGroup("Rows") {
                ListRow("Domains", subtitle: "Manage domains", systemImage: "globe", badge: "3", showChevron: true)
                ListRow(verbatim: "Plain") { Text(verbatim: "x") }
                ListRow("Disabled", systemImage: "lock").disabled(true)
            }
            InfoGroup("Info", rows: [
                InfoItem("Name", value: "example.net", copyable: true),
                InfoItem("Key", value: "secret123", copyable: true, sensitive: true, monospaced: true),
                InfoItem("Empty", value: nil),
            ])
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
