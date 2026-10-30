import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                StatusCard()
                BigPadButton()
                ResultLine()
                ShortcutEditor()
            }
            .frame(maxWidth: 560)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - Status

private struct StatusCard: View {
    @EnvironmentObject private var model: PadModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(model.macConnected ? Color.green : Color.orange)
                    .frame(width: 12, height: 12)
                Text(model.macConnected ? "Mac verbunden" : "Warte auf Mac-Helper")
                    .font(.headline)
            }
            Text(model.detailText)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Der große Test-Button

private struct BigPadButton: View {
    @EnvironmentObject private var model: PadModel

    var body: some View {
        Button {
            model.trigger()
        } label: {
            VStack(spacing: 10) {
                Text(model.shortcut.isValid ? model.shortcut.displayString : "–")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(model.macConnected ? "Tippen zum Senden" : "Nicht verbunden")
                    .font(.callout)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(model.macConnected && model.shortcut.isValid ? Color.accentColor : Color.gray)
            )
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!model.shortcut.isValid)
    }
}

private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ResultLine: View {
    @EnvironmentObject private var model: PadModel

    var body: some View {
        if let text = model.resultText {
            Text((model.resultOK == true ? "✓ " : "✗ ") + text)
                .font(.footnote)
                .foregroundColor(model.resultOK == true ? .green : .red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Kürzel festlegen

private struct ShortcutEditor: View {
    @EnvironmentObject private var model: PadModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Kürzel für die Mac-Tastatur")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(KeyModifier.allCases) { modifier in
                    ModifierChip(
                        modifier: modifier,
                        isOn: Binding(
                            get: { model.shortcut.modifiers.contains(modifier) },
                            set: { model.setModifier(modifier, enabled: $0) }
                        )
                    )
                }
            }

            Picker("Tastenart", selection: Binding(
                get: { model.isNamedKey },
                set: { model.setNamedMode($0) }
            )) {
                Text("Zeichen").tag(false)
                Text("Sondertaste").tag(true)
            }
            .pickerStyle(.segmented)

            if model.isNamedKey {
                Picker("Taste", selection: Binding(
                    get: { model.shortcut.namedKey ?? .returnKey },
                    set: { model.shortcut.key = $0.rawValue }
                )) {
                    ForEach(NamedKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }
                .pickerStyle(.menu)
            } else {
                TextField("Taste, z. B. b", text: Binding(
                    get: { model.shortcut.key },
                    set: { model.setCharacter($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            Text("Zeichen werden am Mac anhand des aktuellen Tastaturlayouts in die passende Taste übersetzt.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ModifierChip: View {
    let modifier: KeyModifier
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VStack(spacing: 2) {
                Text(modifier.symbol).font(.title2)
                Text(modifier.title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(isOn ? .white : .primary)
            .background(isOn ? Color.accentColor : Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
