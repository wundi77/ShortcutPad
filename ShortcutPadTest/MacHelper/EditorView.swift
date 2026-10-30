import SwiftUI

enum EditorSheet: Identifiable {
    case settings(UUID)
    case recorder(UUID)
    case importExport(UUID?)
    case group(UUID)

    var id: String {
        switch self {
        case .settings(let id): return "settings-\(id.uuidString)"
        case .recorder(let id): return "recorder-\(id.uuidString)"
        case .importExport(let id): return "ie-\(id?.uuidString ?? "alle")"
        case .group(let id): return "group-\(id.uuidString)"
        }
    }
}

/// Hauptfenster der Mac-App: Sets links, Pad-Vorschau in der Mitte, Button-Eigenschaften rechts.
struct EditorView: View {
    @EnvironmentObject private var store: SetStore
    @EnvironmentObject private var controller: HelperController
    @Environment(\.openWindow) private var openWindow

    @State private var selectedSetID: UUID? = nil
    @State private var selectedButtonID: UUID? = nil
    @State private var device: PadDevice = .tabletLandscape
    @State private var sheet: EditorSheet? = nil

    private var currentSet: PadSet? {
        store.set(withID: selectedSetID) ?? store.sets.first
    }

    private var currentButton: PadButton? {
        guard let id = selectedButtonID else { return nil }
        return currentSet?.buttons.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.line).frame(width: 1)
            center
            Rectangle().fill(Theme.line).frame(width: 1)
            inspector
        }
        .frame(minWidth: 1180, minHeight: 740)
        .background(Theme.window)
        .foregroundColor(Theme.text)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                connectionChip
            }
        }
        .sheet(item: $sheet) { item in
            sheetContent(item)
        }
        .onAppear { ensureSelection() }
        .onChange(of: store.sets) { _ in ensureSelection() }
    }

    private func ensureSelection() {
        if store.set(withID: selectedSetID) == nil {
            selectedSetID = store.set(withID: controller.activeSetID)?.id ?? store.sets.first?.id
        }
        if let id = selectedButtonID, currentSet?.buttons.contains(where: { $0.id == id }) != true {
            selectedButtonID = nil
        }
    }

    // MARK: Statuszeile

    private var connectionChip: some View {
        Button {
            openWindow(id: "connection")
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(controller.linkedDeviceName != nil || controller.webPairedCount > 0 ? Theme.live : Theme.muted)
                    .frame(width: 8, height: 8)
                Text(connectionText)
                    .font(.system(size: 12.5))
            }
        }
        .help("Verbindung und Kopplung öffnen")
    }

    private var connectionText: String {
        var parts = [String]()
        if let name = controller.linkedDeviceName {
            parts.append("\(name) · USB")
        } else {
            parts.append("Kein Gerät per USB")
        }
        if controller.webRunning {
            parts.append("Web · \(controller.webPairedCount) Gerät(e)")
        }
        return parts.joined(separator: "  |  ")
    }

    // MARK: Sets

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            FieldLabel("Sets")
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(store.sets) { set in
                        setRow(set)
                    }
                }
                .padding(.horizontal, 10)
            }

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Button {
                        if let id = store.addSet() {
                            selectedSetID = id
                            selectedButtonID = nil
                            sheet = .settings(id)
                        }
                    } label: {
                        Label("Neues Set", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FlatButtonStyle(kind: .secondary, compact: true))

                    Button {
                        sheet = .importExport(nil)
                    } label: {
                        Text("Import / Export")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FlatButtonStyle(kind: .secondary, compact: true))
                }
                Text("Buttons und Kürzel lassen sich nur hier bearbeiten. iPad, iPhone und die Webseite zeigen sie an.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .frame(width: 240)
        .frame(maxHeight: .infinity)
        .background(Theme.sidebar)
    }

    private func setRow(_ set: PadSet) -> some View {
        let isSelected = currentSet?.id == set.id
        return Button {
            selectedSetID = set.id
            selectedButtonID = nil
        } label: {
            HStack(spacing: 10) {
                Circle().fill(set.color.color).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(set.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(set.appName ?? "Alle anderen Programme")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if controller.activeSetID == set.id {
                    HStack(spacing: 5) {
                        Circle().fill(Theme.live).frame(width: 6, height: 6)
                        Text("aktiv")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(Theme.live)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(isSelected ? Theme.raised : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Set-Einstellungen …") { sheet = .settings(set.id) }
            Button("Exportieren …") { sheet = .importExport(set.id) }
            Divider()
            Button("Nach oben") { store.moveSet(set.id, by: -1) }
            Button("Nach unten") { store.moveSet(set.id, by: 1) }
        }
    }

    // MARK: Mitte

    @ViewBuilder
    private var center: some View {
        if let set = currentSet {
            VStack(spacing: 0) {
                centerHeader(set)
                controlsRow(set)
                PadPreview(
                    set: set,
                    device: device,
                    selectedID: $selectedButtonID,
                    isConnected: controller.linkedDeviceName != nil || controller.webPairedCount > 0,
                    onMove: { dragged, target in store.moveButton(dragged, onto: target, in: set.id) },
                    onAdd: { addButton() }
                )
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                legendRow(set)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                Text("Noch kein Set")
                    .font(.system(size: 20, weight: .bold))
                Text("Lege links ein neues Set an.")
                    .foregroundColor(Theme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func centerHeader(_ set: PadSet) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(set.name)
                    .font(.system(size: 24, weight: .heavy))
                    .lineLimit(1)
                Text(subtitle(for: set))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
            Spacer()
            Button("Set-Einstellungen") { sheet = .settings(set.id) }
                .buttonStyle(FlatButtonStyle(kind: .secondary))
            Button {
                addButton()
            } label: {
                Label("Button", systemImage: "plus")
            }
            .buttonStyle(FlatButtonStyle(kind: .primary))
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
    }

    private func subtitle(for set: PadSet) -> String {
        let program = set.appName ?? "Alle anderen Programme"
        let mode = (set.appBundleID != nil && set.autoSwitch) ? "wechselt automatisch" : "wechselt nicht automatisch"
        return "\(program) · \(mode) · \(set.buttons.count) Buttons"
    }

    private func controlsRow(_ set: PadSet) -> some View {
        HStack(spacing: 12) {
            Picker("Gerät", selection: $device) {
                ForEach(PadDevice.allCases) { device in
                    Text(device.title).tag(device)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 380)

            Spacer()

            FieldLabel("Stil")
            Picker("Stil", selection: styleBinding(set)) {
                ForEach(PadStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 210)
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
    }

    private func styleBinding(_ set: PadSet) -> Binding<PadStyle> {
        Binding(
            get: { store.set(withID: set.id)?.style ?? set.style },
            set: { value in store.mutate(set.id) { $0.style = value } }
        )
    }

    private func legendRow(_ set: PadSet) -> some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(set.groups) { group in
                        Button {
                            sheet = .group(group.id)
                        } label: {
                            HStack(spacing: 7) {
                                Circle().fill(group.color.color).frame(width: 9, height: 9)
                                Text(group.name).font(.system(size: 12.5, weight: .semibold))
                                Text("\(set.buttons.filter { $0.groupID == group.id }.count)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Theme.muted)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Theme.tile))
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        if let id = store.addGroup(to: set.id) {
                            sheet = .group(id)
                        }
                    } label: {
                        Text("+ Gruppe")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(Theme.muted)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .overlay(Capsule().stroke(Color(hex: 0x4A4D57), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }

            Button("Nach Gruppe sortieren") { store.sortByGroup(in: set.id) }
                .buttonStyle(FlatButtonStyle(kind: .plain, compact: true))
            Text("Ziehen zum Anordnen · Klick zum Bearbeiten")
                .font(.system(size: 11.5))
                .foregroundColor(Theme.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 18)
    }

    // MARK: Button-Eigenschaften

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let set = currentSet, let button = currentButton {
                    inspectorContent(set: set, button: button)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Button")
                            .font(.system(size: 15, weight: .bold))
                        Text("Wähle einen Button in der Vorschau, um Beschriftung, Kürzel und Farbe zu ändern.")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 320)
        .frame(maxHeight: .infinity)
        .background(Theme.sidebar)
    }

    private func inspectorContent(set: PadSet, button: PadButton) -> some View {
        let number = (set.buttons.firstIndex { $0.id == button.id } ?? 0) + 1
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Button").font(.system(size: 15, weight: .bold))
                Spacer()
                Text("\(number) / \(set.buttons.count)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.muted)
            }

            HStack {
                Spacer()
                PadTileView(
                    label: button.label,
                    keys: button.shortcut.displayString,
                    color: set.color(for: button).color,
                    filled: set.isFilled(button),
                    showKeys: set.showShortcuts,
                    size: 112,
                    fontScale: 1.2
                )
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Beschriftung")
                PadTextField(
                    placeholder: "Text auf dem Button",
                    text: Binding(
                        get: { button.label },
                        set: { value in
                            updateButton { $0.label = String(value.prefix(PadLimits.maxLabelLength)) }
                        }
                    )
                )
                Text("Kurz halten, höchstens zwei Zeilen. Kein Symbol, nur Text.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Kürzel")
                HStack(spacing: 8) {
                    KeyCapsRow(shortcut: button.shortcut)
                    Spacer(minLength: 4)
                    Button("Aufnehmen") { sheet = .recorder(button.id) }
                        .buttonStyle(FlatButtonStyle(kind: .secondary, compact: true))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Farbe")
                SwatchRow(selected: button.colorOverride) { color in
                    updateButton { $0.colorOverride = color }
                }
                HStack {
                    Text(colorHint(set: set, button: button))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0xB9BCC5))
                    Spacer()
                    Button("Wie Gruppe") { updateButton { $0.colorOverride = nil } }
                        .buttonStyle(FlatButtonStyle(kind: .secondary, compact: true))
                        .disabled(button.colorOverride == nil)
                }
                Toggle("Betont (im Stil „Betont“ voll gezeichnet)", isOn: Binding(
                    get: { button.emphasized },
                    set: { value in updateButton { $0.emphasized = value } }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 12.5))
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Gruppe")
                Picker("Gruppe", selection: Binding(
                    get: { button.groupID },
                    set: { value in updateButton { $0.groupID = value } }
                )) {
                    Text("Keine").tag(UUID?.none)
                    ForEach(set.groups) { group in
                        Text(group.name).tag(UUID?.some(group.id))
                    }
                }
                .labelsHidden()
            }

            HStack(spacing: 8) {
                Button("Am Mac testen") {
                    controller.test(button.shortcut, targetBundleID: set.appBundleID)
                }
                .buttonStyle(FlatButtonStyle(kind: .secondary))
                Button("Duplizieren") {
                    if let id = store.duplicateButton(button.id, in: set.id) {
                        selectedButtonID = id
                    }
                }
                .buttonStyle(FlatButtonStyle(kind: .secondary))
                Spacer(minLength: 0)
                Button("Löschen") {
                    store.deleteButton(button.id, in: set.id)
                    selectedButtonID = nil
                }
                .buttonStyle(FlatButtonStyle(kind: .danger))
            }
        }
    }

    private func colorHint(set: PadSet, button: PadButton) -> String {
        if let own = button.colorOverride {
            return "Eigene Farbe: \(own.title)"
        }
        if let group = set.group(for: button) {
            return "Farbe der Gruppe \(group.name) (\(group.color.title))"
        }
        return "Farbe des Sets (\(set.color.title))"
    }

    // MARK: Aktionen

    private func addButton() {
        guard let set = currentSet else { return }
        if let id = store.addButton(to: set.id) {
            selectedButtonID = id
            sheet = .recorder(id)
        }
    }

    private func updateButton(_ change: (inout PadButton) -> Void) {
        guard let setID = currentSet?.id, let buttonID = selectedButtonID else { return }
        store.updateButton(buttonID, in: setID, change)
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetContent(_ item: EditorSheet) -> some View {
        switch item {
        case .settings(let id):
            if let set = store.set(withID: id) {
                SetSettingsSheet(
                    set: set,
                    onExport: { exportID in sheet = .importExport(exportID) },
                    onClose: { sheet = nil }
                )
                .environmentObject(store)
            }
        case .recorder(let buttonID):
            if let set = currentSet, let button = set.buttons.first(where: { $0.id == buttonID }) {
                ShortcutRecorderSheet(buttonName: button.label, setName: set.name, initial: button.shortcut) { result in
                    if let shortcut = result {
                        store.updateButton(buttonID, in: set.id) { $0.shortcut = shortcut }
                    }
                    sheet = nil
                }
            }
        case .importExport(let preselect):
            ImportExportSheet(preselect: preselect, allIDs: store.sets.map { $0.id }) {
                sheet = nil
            }
            .environmentObject(store)
        case .group(let groupID):
            if let set = currentSet {
                GroupSheet(setID: set.id, groupID: groupID) { sheet = nil }
                    .environmentObject(store)
            }
        }
    }
}
