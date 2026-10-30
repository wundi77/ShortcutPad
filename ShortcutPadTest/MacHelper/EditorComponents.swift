import SwiftUI

// MARK: - Buttons im Stil der Oberfläche

struct FlatButtonStyle: ButtonStyle {
    enum Kind {
        case primary, secondary, danger, plain
    }

    var kind: Kind = .secondary
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        FlatButtonBody(configuration: configuration, kind: kind, compact: compact)
    }
}

private struct FlatButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: FlatButtonStyle.Kind
    let compact: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 5 : 8)
            .foregroundColor(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(kind == .danger ? Color(hex: 0x5A2A33) : Color.clear, lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Color.white
        case .secondary: return Color(hex: 0xE6E8EC)
        case .danger: return Theme.danger
        case .plain: return Theme.muted
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return Theme.accent
        case .secondary: return Theme.control
        case .danger, .plain: return Color.clear
        }
    }
}

// MARK: - Kleine Bausteine

struct FieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .tracking(1.1)
            .foregroundColor(Theme.muted)
    }
}

/// Eine Taste in der Schreibweise des Designs („⇧“, „⌘“, „N“).
struct KeyCap: View {
    let symbol: String
    var large = false

    var body: some View {
        Text(symbol)
            .font(.system(size: large ? 30 : 17, weight: .medium, design: .monospaced))
            .foregroundColor(Theme.text)
            .padding(.horizontal, large ? 14 : 9)
            .frame(minWidth: large ? 64 : 36, minHeight: large ? 68 : 38)
            .background(
                RoundedRectangle(cornerRadius: large ? 14 : 8, style: .continuous)
                    .fill(Theme.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: large ? 14 : 8, style: .continuous)
                    .stroke(Color(hex: 0x3B3E47), lineWidth: 1)
            )
    }
}

extension Shortcut {
    /// Tasten einzeln, in der Reihenfolge ⌃ ⌥ ⇧ ⌘ und dann die Taste selbst.
    var capSymbols: [String] {
        let order: [KeyModifier] = [.control, .option, .shift, .command]
        return order.filter { modifiers.contains($0) }.map { $0.symbol } + [keyDisplay]
    }
}

struct KeyCapsRow: View {
    let shortcut: Shortcut
    var large = false

    var body: some View {
        HStack(spacing: large ? 10 : 6) {
            ForEach(Array(shortcut.capSymbols.enumerated()), id: \.offset) { entry in
                KeyCap(symbol: entry.element, large: large)
            }
        }
    }
}

struct SwatchRow: View {
    let selected: PadColor?
    var diameter: CGFloat = 26
    var spacing: CGFloat = 8
    let onPick: (PadColor) -> Void

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(PadColor.allCases) { color in
                Button {
                    onPick(color)
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: diameter, height: diameter)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: selected == color ? 2 : 0)
                                .padding(-3)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(color.title))
            }
        }
        .padding(3)
    }
}

/// Eingabefeld im Stil der Oberfläche.
struct PadTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundColor(Theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.field))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.fieldLine, lineWidth: 1))
    }
}

/// Beschriftete Bedienelemente in Sheets (Rand, Hintergrund).
struct SheetContainer<Content: View>: View {
    let width: CGFloat
    let content: Content

    init(width: CGFloat, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 24)
            .frame(width: width)
            .background(Color(hex: 0x26272C))
            .preferredColorScheme(.dark)
    }
}
