import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Set-Einstellungen

struct SetSettingsSheet: View {
    @EnvironmentObject private var store: SetStore

    let onExport: (UUID) -> Void
    let onClose: () -> Void

    @State private var draft: PadSet
    @State private var confirmDelete = false

    init(set: PadSet, onExport: @escaping (UUID) -> Void, onClose: @escaping () -> Void) {
        _draft = State(initialValue: set)
        self.onExport = onExport
        self.onClose = onClose
    }

    private struct AppChoice: Identifiable {
        let id: String
        let name: String
    }

    var body: some View {
        SheetContainer(width: 520) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Set-Einstellungen")
                    .font(.system(size: 19, weight: .bold))

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel("Name")
                    PadTextField(placeholder: "Name des Sets", text: nameBinding)
                }

                programSection

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel("Set-Farbe")
                    SwatchRow(selected: draft.color) { color in draft.color = color }
                    Text("Standardfarbe für neue Gruppen und Buttons in diesem Set.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                }

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel("Button-Stil")
                    HStack(spacing: 10) {
                        ForEach(PadStyle.allCases) { style in
                            styleCard(style)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel("Buttongröße")
                    HStack(alignment: .center, spacing: 14) {
                        Picker("Größe", selection: $draft.size) {
                            ForEach(PadSize.allCases) { size in
                                Text(size.title).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 210)
                        Text("Mindestgröße \(Int(draft.size.minTile(tablet: false))) pt am iPhone, \(Int(draft.size.minTile(tablet: true))) pt am iPad. Darunter werden Buttons nie kleiner, es kommen Zeilen dazu.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Toggle("Kürzel klein auf dem Button zeigen", isOn: $draft.showShortcuts)
                        .toggleStyle(.switch)
                        .font(.system(size: 13.5))
                }

                HStack(spacing: 10) {
                    Button(confirmDelete ? "Wirklich löschen" : "Set löschen") {
                        if confirmDelete {
                            store.deleteSet(draft.id)
                            onClose()
                        } else {
                            confirmDelete = true
                        }
                    }
                    .buttonStyle(FlatButtonStyle(kind: .danger, compact: true))
                    Spacer()
                    Button("Exportieren") {
                        store.replace(draft)
                        onExport(draft.id)
                    }
                    .buttonStyle(FlatButtonStyle(kind: .secondary))
                    Button("Abbrechen") { onClose() }
                        .buttonStyle(FlatButtonStyle(kind: .secondary))
                        .keyboardShortcut(.cancelAction)
                    Button("Fertig") {
                        store.replace(draft)
                        onClose()
                    }
                    .buttonStyle(FlatButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { draft.name },
            set: { draft.name = String($0.prefix(PadLimits.maxNameLength)) }
        )
    }

    // MARK: Programm

    private var programSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel("Programm")
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.appName ?? "Alle anderen Programme")
                        .font(.system(size: 14, weight: .semibold))
                    Text(draft.appBundleID ?? "Rückfall, wenn kein anderes Set passt")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.muted)
                }
                Spacer()
                Menu("Ändern") {
                    ForEach(runningApps()) { app in
                        Button(app.name) {
                            draft.appBundleID = app.id
                            draft.appName = app.name
                        }
                    }
                    Divider()
                    Button("Programm aus Ordner wählen …") { chooseApp() }
                    Button("Kein Programm (für alle anderen)") {
                        draft.appBundleID = nil
                        draft.appName = nil
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: 0x1F2024)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(hex: 0x3B3E47), lineWidth: 1))

            Toggle("Automatisch umschalten, sobald das Programm am Mac vorne ist", isOn: $draft.autoSwitch)
                .toggleStyle(.switch)
                .font(.system(size: 13.5))
                .disabled(draft.appBundleID == nil)
        }
    }

    private func runningApps() -> [AppChoice] {
        var seen = Set<String>()
        var result = [AppChoice]()
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let id = app.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier,
                  !seen.contains(id) else { continue }
            seen.insert(id)
            result.append(AppChoice(id: id, name: app.localizedName ?? id))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Programm für dieses Set wählen"
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        draft.appBundleID = id
        draft.appName = name
    }

    // MARK: Stil-Karten

    private func styleCard(_ style: PadStyle) -> some View {
        let selected = draft.style == style
        let sample: [PadColor] = [.blau, .indigo, .orange, .rot, .gruen, .tuerkis]
        return Button {
            draft.style = style
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(Array(sample.enumerated()), id: \.offset) { entry in
                        let filled = style == .fill || (style == .mix && entry.offset % 3 == 0)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(filled ? entry.element.color : Theme.tile)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                VStack {
                                    Spacer()
                                    if !filled {
                                        Capsule().fill(entry.element.color).frame(height: 2).padding(.horizontal, 7).padding(.bottom, 4)
                                    }
                                }
                            )
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.title).font(.system(size: 13, weight: .bold))
                    Text(style.summary)
                        .font(.system(size: 11.5))
                        .foregroundColor(Color(hex: 0xA3A6AF))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: 0x1F2024)))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Color(hex: 0x5B9BFF) : Color(hex: 0x3B3E47), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(Theme.text)
    }
}

// MARK: - Import und Export

struct ImportExportSheet: View {
    @EnvironmentObject private var store: SetStore

    let onClose: () -> Void

    @State private var selected: Set<UUID>
    @State private var mode: ImportMode = .addAsNew
    @State private var message: String? = nil
    @State private var messageIsError = false
    @State private var dropTargeted = false

    init(preselect: UUID?, allIDs: [UUID], onClose: @escaping () -> Void) {
        if let id = preselect {
            _selected = State(initialValue: [id])
        } else {
            _selected = State(initialValue: Set(allIDs))
        }
        self.onClose = onClose
    }

    var body: some View {
        SheetContainer(width: 520) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sets importieren und exportieren")
                        .font(.system(size: 19, weight: .bold))
                    Text("Ein Set liegt als Datei vor (.shortcutpad). Damit sicherst du deine Sets oder nimmst sie auf einen anderen Mac mit.")
                        .font(.system(size: 13.5))
                        .foregroundColor(Color(hex: 0xB4B7C0))
                        .fixedSize(horizontal: false, vertical: true)
                }

                exportSection

                Divider().background(Color(hex: 0x3A3C44))

                importSection

                if let message = message {
                    Text(message)
                        .font(.system(size: 12.5))
                        .foregroundColor(messageIsError ? Theme.danger : Theme.live)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer()
                    Button("Schließen") { onClose() }
                        .buttonStyle(FlatButtonStyle(kind: .secondary))
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
    }

    // MARK: Export

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("Exportieren")
            VStack(spacing: 0) {
                ForEach(store.sets) { set in
                    Toggle(isOn: Binding(
                        get: { selected.contains(set.id) },
                        set: { isOn in
                            if isOn { selected.insert(set.id) } else { selected.remove(set.id) }
                        }
                    )) {
                        HStack(spacing: 10) {
                            Circle().fill(set.color.color).frame(width: 10, height: 10)
                            Text(set.name).font(.system(size: 14))
                            Spacer()
                            Text("\(set.buttonCount) Buttons")
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundColor(Theme.muted)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(.vertical, 5)
                }
            }
            HStack(spacing: 12) {
                Text("Enthält Buttons, Kürzel, Farben, Stil und Programmzuordnung.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Exportieren …") { exportSelected() }
                    .buttonStyle(FlatButtonStyle(kind: .primary))
                    .disabled(selected.isEmpty)
            }
        }
    }

    private func exportSelected() {
        let ids = store.sets.map { $0.id }.filter { selected.contains($0) }
        guard !ids.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["shortcutpad"]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = (ids.count == 1 ? (store.set(withID: ids[0])?.name ?? "Set") : "ShortcutPad Sets") + ".shortcutpad"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try store.exportData(setIDs: ids)
            try data.write(to: url, options: .atomic)
            show("\(ids.count) Set(s) exportiert nach \(url.lastPathComponent).", error: false)
        } catch {
            show("Export fehlgeschlagen: \(error.localizedDescription)", error: true)
        }
    }

    // MARK: Import

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel("Importieren")
            VStack(spacing: 10) {
                Text("Datei hier ablegen")
                    .font(.system(size: 13.5))
                    .foregroundColor(Color(hex: 0xD5D7DD))
                Button("Datei wählen …") { chooseFile() }
                    .buttonStyle(FlatButtonStyle(kind: .secondary, compact: true))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0x1F2024)))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(dropTargeted ? Color(hex: 0x5B9BFF) : Color(hex: 0x4A4D57), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            )
            .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
                handleDrop(providers)
            }

            Picker("Beim Import", selection: $mode) {
                Text("Als neues Set hinzufügen").tag(ImportMode.addAsNew)
                Text("Set mit gleichem Namen ersetzen").tag(ImportMode.replaceSameName)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["shortcutpad", "json"]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(url)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let direct = item as? URL {
                url = direct
            }
            guard let fileURL = url else { return }
            DispatchQueue.main.async { importFile(fileURL) }
        }
        return true
    }

    private func importFile(_ url: URL) {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard size <= PadLimits.maxFileBytes else {
            show(SetStoreError.tooLarge.localizedDescription, error: true)
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let imported = try store.importData(data, mode: mode)
            let names = imported.map { $0.name }.joined(separator: ", ")
            show("\(imported.count) Set(s) importiert: \(names)", error: false)
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    private func show(_ text: String, error: Bool) {
        message = text
        messageIsError = error
    }
}

// MARK: - Gruppe bearbeiten

struct GroupSheet: View {
    @EnvironmentObject private var store: SetStore

    let setID: UUID
    let groupID: UUID
    let onClose: () -> Void

    init(setID: UUID, groupID: UUID, onClose: @escaping () -> Void) {
        self.setID = setID
        self.groupID = groupID
        self.onClose = onClose
    }

    private var group: PadGroup? {
        store.set(withID: setID)?.groups.first { $0.id == groupID }
    }

    var body: some View {
        SheetContainer(width: 420) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Gruppe")
                    .font(.system(size: 19, weight: .bold))

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel("Name")
                    PadTextField(
                        placeholder: "Name der Gruppe",
                        text: Binding(
                            get: { group?.name ?? "" },
                            set: { value in
                                store.updateGroup(groupID, in: setID) { $0.name = String(value.prefix(PadLimits.maxNameLength)) }
                            }
                        )
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel("Farbe")
                    SwatchRow(selected: group?.color) { color in
                        store.updateGroup(groupID, in: setID) { $0.color = color }
                    }
                    Text("Alle Buttons der Gruppe nehmen diese Farbe, sofern sie keine eigene haben.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                }

                HStack {
                    Button("Gruppe löschen") {
                        store.deleteGroup(groupID, in: setID)
                        onClose()
                    }
                    .buttonStyle(FlatButtonStyle(kind: .danger, compact: true))
                    Spacer()
                    Button("Fertig") { onClose() }
                        .buttonStyle(FlatButtonStyle(kind: .primary))
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}
