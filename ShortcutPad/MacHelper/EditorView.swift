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

/// Hauptfenster der Mac-App: Sets links, Pad-Vorschau in der Mitte, Eigenschaften rechts.
struct EditorView: View {
    @EnvironmentObject private var store: SetStore
    @EnvironmentObject private var controller: HelperController
    @Environment(\.openWindow) private var openWindow

    @State private var selectedSetID: UUID? = nil
    /// Ausgewählter Eintrag: Button oder Ordner.
    @State private var selectedID: UUID? = nil
    /// Geöffneter Ordner (Ordnerseite). Nil: Hauptebene.
    @State private var openFolderID: UUID? = nil
    @State private var device: PadDevice = .tabletLandscape
    @State private var sheet: EditorSheet? = nil
    /// Ordner, dessen Löschen (samt Buttons) noch bestätigt werden muss.
    @State private var confirmDeleteFolderID: UUID? = nil

    private var currentSet: PadSet? {
        store.set(withID: selectedSetID) ?? store.sets.first
    }

    private var currentFolder: PadFolder? {
        currentSet?.folder(withID: openFolderID)
    }

    private var selectedButton: PadButton? {
        currentSet?.button(withID: selectedID)
    }

    private var selectedFolder: PadFolder? {
        currentSet?.folder(withID: selectedID)
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
            openFolderID = nil
        }
        guard let set = currentSet else { return }
        if openFolderID != nil && set.folder(withID: openFolderID) == nil {
            openFolderID = nil
        }
        if let id = selectedID, set.button(withID: id) == nil, set.folder(withID: id) == nil {
            selectedID = nil
        }
    }

    // MARK: Navigation

    private func openFolder(_ id: UUID) {
        guard currentSet?.folder(withID: id) != nil else { return }
        openFolderID = id
        selectedID = nil
        confirmDeleteFolderID = nil
    }

    private func closeFolder() {
        selectedID = openFolderID
        openFolderID = nil
        confirmDeleteFolderID = nil
    }

    private func selectSet(_ id: UUID) {
        selectedSetID = id
        selectedID = nil
        openFolderID = nil
        confirmDeleteFolderID = nil
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
                VStack(spacing: 8) {
                    Button {
                        if let id = store.addSet() {
                            selectSet(id)
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
            selectSet(set.id)
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
                breadcrumbRow(set)
                PadPreview(
                    set: set,
                    folder: currentFolder,
                    device: device,
                    selectedID: $selectedID,
                    isConnected: controller.linkedDeviceName != nil || controller.webPairedCount > 0,
                    onOpen: { id in openFolder(id) },
                    onBack: { closeFolder() },
                    onReorder: { dragged, target in store.reorder(dragged, onto: target, in: set.id) },
                    onDropInto: { button, folder in store.moveButton(button, to: folder, in: set.id) },
                    onDropToTop: { button in store.moveButton(button, to: nil, in: set.id) },
                    onAdd: { addButton() }
                )
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
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
                if let id = store.addFolder(to: set.id) {
                    openFolderID = nil
                    selectedID = id
                }
            } label: {
                Label("Ordner", systemImage: "folder")
            }
            .buttonStyle(FlatButtonStyle(kind: .secondary))
            .disabled(currentFolder != nil)
            .help(currentFolder != nil ? "Ordner gibt es nur auf der Hauptebene." : "Neuen Ordner anlegen")
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
        return "\(program) · \(mode) · \(set.items.count) Elemente, \(set.buttonCount) Buttons"
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

    /// „Photoshop › Ebenen“: Wo bin ich? Ein Klick auf den Set-Namen geht zurück auf die Hauptebene.
    private func breadcrumbRow(_ set: PadSet) -> some View {
        HStack(spacing: 8) {
            Button {
                if currentFolder != nil { closeFolder() }
            } label: {
                HStack(spacing: 7) {
                    Circle().fill(set.color.color).frame(width: 9, height: 9)
                    Text(set.name).font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(currentFolder == nil ? Theme.raised : Theme.tile))
            }
            .buttonStyle(.plain)

            if let folder = currentFolder {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.muted)
                HStack(spacing: 7) {
                    Image(systemName: "folder")
                        .font(.system(size: 11, weight: .semibold))
                    Text(folder.name).font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.raised))
            }

            Spacer()
            Text(levelInfo(set))
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundColor(Theme.muted)
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
    }

    private func levelInfo(_ set: PadSet) -> String {
        if let folder = currentFolder {
            return "\(folder.buttons.count) Buttons in diesem Ordner · zurück mit der Kachel „<“"
        }
        return "\(set.items.count) Elemente auf der Hauptebene (\(set.folders.count) Ordner)"
    }

    private func legendRow(_ set: PadSet) -> some View {
        let allButtons = set.allButtons
        return VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(set.groups) { group in
                    Button {
                        sheet = .group(group.id)
                    } label: {
                        HStack(spacing: 7) {
                            Circle().fill(group.color.color).frame(width: 9, height: 9)
                            Text(group.name)
                                .font(.system(size: 12.5, weight: .semibold))
                                .lineLimit(1)
                            Text("\(allButtons.filter { $0.groupID == group.id }.count)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.muted)
                        }
                        .fixedSize()
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
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .overlay(Capsule().stroke(Color(hex: 0x4A4D57), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button("Nach Gruppe sortieren") { store.sortByGroup(in: set.id, folderID: openFolderID) }
                    .buttonStyle(FlatButtonStyle(kind: .secondary, compact: true))
                Spacer()
                Text("Ziehen zum Anordnen, auf einen Ordner ziehen zum Ablegen · Doppelklick öffnet einen Ordner")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 18)
    }

    // MARK: Eigenschaften

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let set = currentSet, let folder = selectedFolder {
                    folderInspector(set: set, folder: folder)
                } else if let set = currentSet, let button = selectedButton {
                    buttonInspector(set: set, button: button)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nichts ausgewählt")
                            .font(.system(size: 15, weight: .bold))
                        Text("Wähle einen Button oder Ordner in der Vorschau, um Beschriftung, Kürzel und Farbe zu ändern.")
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

    private func buttonInspector(set: PadSet, button: PadButton) -> some View {
        let all = set.allButtons
        let number = (all.firstIndex { $0.id == button.id } ?? 0) + 1
        let parent = set.folder(withID: set.folderID(containing: button.id))
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Button").font(.system(size: 15, weight: .bold))
                Spacer()
                Text(parent.map { "in „\($0.name)“" } ?? "Hauptebene")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
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
                Text("Kurz halten, höchstens zwei Zeilen. Kein Symbol, nur Text. Nummer \(number) von \(all.count).")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Kürzel")
                KeyCapsRow(shortcut: button.shortcut)
                Button("Aufnehmen") { sheet = .recorder(button.id) }
                    .buttonStyle(FlatButtonStyle(kind: .secondary, compact: true))
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

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Ablegen in")
                Picker("Ablegen in", selection: Binding(
                    get: { set.folderID(containing: button.id) },
                    set: { value in moveSelectedButton(to: value) }
                )) {
                    Text("Hauptebene").tag(UUID?.none)
                    ForEach(set.folders) { folder in
                        Text("Ordner „\(folder.name)“").tag(UUID?.some(folder.id))
                    }
                }
                .labelsHidden()
                Text("Alternative zum Ziehen.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
            }

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    controller.test(button.shortcut, targetBundleID: set.appBundleID)
                } label: {
                    Text("Am Mac testen").frame(maxWidth: .infinity)
                }
                .buttonStyle(FlatButtonStyle(kind: .secondary))

                HStack(spacing: 8) {
                    Button {
                        if let id = store.duplicateButton(button.id, in: set.id) {
                            selectedID = id
                        }
                    } label: {
                        Text("Duplizieren").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FlatButtonStyle(kind: .secondary))

                    Button {
                        store.deleteButton(button.id, in: set.id)
                        selectedID = nil
                    } label: {
                        Text("Löschen").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FlatButtonStyle(kind: .danger))
                }
            }
        }
    }

    private func folderInspector(set: PadSet, folder: PadFolder) -> some View {
        let confirming = confirmDeleteFolderID == folder.id
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ordner").font(.system(size: 15, weight: .bold))
                Spacer()
                Text("Hauptebene")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.muted)
            }

            HStack {
                Spacer()
                PadTileView(
                    label: folder.name,
                    keys: folder.buttons.count == 1 ? "1 Button" : "\(folder.buttons.count) Buttons",
                    color: folder.color.color,
                    filled: set.isFilled(folder),
                    showKeys: true,
                    size: 112,
                    fontScale: 1.2,
                    isFolder: true
                )
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Name")
                PadTextField(
                    placeholder: "Name des Ordners",
                    text: Binding(
                        get: { folder.name },
                        set: { value in
                            store.updateFolder(folder.id, in: set.id) { $0.name = String(value.prefix(PadLimits.maxNameLength)) }
                        }
                    )
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Farbe")
                SwatchRow(selected: folder.color) { color in
                    store.updateFolder(folder.id, in: set.id) { $0.color = color }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("Inhalt")
                Text(folder.buttons.count == 1 ? "1 Button" : "\(folder.buttons.count) Buttons")
                    .font(.system(size: 14))
                Text("Ordner gibt es nur auf der Hauptebene. Am Gerät öffnet ein Tipp die Ordnerseite, die Zurück-Kachel steht dort an erster Stelle.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    openFolder(folder.id)
                } label: {
                    Text("Ordner öffnen").frame(maxWidth: .infinity)
                }
                .buttonStyle(FlatButtonStyle(kind: .primary))

                HStack(spacing: 8) {
                    Button {
                        store.dissolveFolder(folder.id, in: set.id)
                        selectedID = nil
                    } label: {
                        Text("Auflösen").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FlatButtonStyle(kind: .secondary))
                    .help("Die Buttons des Ordners kommen an seiner Stelle auf die Hauptebene.")

                    Button {
                        if confirming || folder.buttons.isEmpty {
                            store.deleteFolder(folder.id, in: set.id)
                            selectedID = nil
                            confirmDeleteFolderID = nil
                        } else {
                            confirmDeleteFolderID = folder.id
                        }
                    } label: {
                        Text(confirming ? "Mit Buttons löschen" : "Löschen").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FlatButtonStyle(kind: .danger))
                }
                if confirming {
                    Text("Der Ordner und seine \(folder.buttons.count) Buttons werden gelöscht.")
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.danger)
                }
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
        if let id = store.addButton(to: set.id, in: openFolderID) {
            selectedID = id
            sheet = .recorder(id)
        }
    }

    private func updateButton(_ change: (inout PadButton) -> Void) {
        guard let setID = currentSet?.id, let buttonID = selectedID else { return }
        store.updateButton(buttonID, in: setID, change)
    }

    /// Legt den ausgewählten Button in einen Ordner oder auf die Hauptebene und springt dorthin.
    private func moveSelectedButton(to folderID: UUID?) {
        guard let setID = currentSet?.id, let buttonID = selectedID else { return }
        store.moveButton(buttonID, to: folderID, in: setID)
        openFolderID = folderID
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
            if let set = currentSet, let button = set.button(withID: buttonID) {
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
