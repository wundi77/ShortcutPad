import SwiftUI
import UniformTypeIdentifiers

// MARK: - Farben der Mac-Oberfläche

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension PadColor {
    var color: Color { Color(hex: hex) }
}

/// Farben aus dem Design-Canvas (dunkle Oberfläche).
enum Theme {
    static let window = Color(hex: 0x1E1F23)
    static let sidebar = Color(hex: 0x1A1B1F)
    static let toolbar = Color(hex: 0x232429)
    static let line = Color(hex: 0x2E3036)
    static let tile = Color(hex: 0x25262B)
    static let padBackground = Color(hex: 0x0E0F12)
    static let bezel = Color(hex: 0x08090B)
    static let field = Color(hex: 0x101114)
    static let fieldLine = Color(hex: 0x34363D)
    static let raised = Color(hex: 0x2B2D34)
    static let control = Color(hex: 0x2F3138)
    static let text = Color(hex: 0xF2F3F5)
    static let muted = Color(hex: 0x9A9DA7)
    static let accent = Color(hex: 0x0B63F0)
    static let danger = Color(hex: 0xFF7A8A)
    static let live = Color(hex: 0x4ADE80)
    static let dropTarget = Color(hex: 0x5B9BFF)
}

// MARK: - Ein Button oder Ordner des Pads

/// Zeichnet einen Pad-Button wie im Design: Text, Kürzel klein darunter, Farbe als Balken oder Vollfläche.
/// Ordner haben zusätzlich eine Lasche oben links und zeigen statt des Kürzels die Zahl ihrer Buttons.
struct PadTileView: View {
    let label: String
    let keys: String
    let color: Color
    let filled: Bool
    let showKeys: Bool
    /// Kantenlänge in Punkten.
    let size: CGFloat
    /// Schriftgröße im Verhältnis zur Originalgröße (1 = 1:1).
    let fontScale: CGFloat
    var selected = false
    var isFolder = false
    /// Ein gezogener Button schwebt darüber und würde hier abgelegt.
    var dropTarget = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.19, style: .continuous)
    }

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.19 + 3, style: .continuous)
                    .stroke(Color.white, lineWidth: selected ? 2 : 0)
                    .padding(-4)
            )
            .overlay(
                shape.stroke(Theme.dropTarget, lineWidth: dropTarget ? 3 : 0)
            )
            .scaleEffect(dropTarget ? 1.06 : 1)
    }

    private var content: some View {
        ZStack {
            shape.fill(filled ? color : Theme.tile)

            VStack(spacing: size * 0.04) {
                Text(label)
                    .font(.system(size: 12.5 * fontScale, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if showKeys {
                    Text(keys)
                        .font(.system(size: 9.5 * fontScale, weight: .regular, design: .monospaced))
                        .foregroundColor(filled ? Color.white.opacity(0.88) : Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundColor(filled ? Color.white : Theme.text)
            .padding(.horizontal, size * 0.06)
            .padding(.bottom, filled ? 0 : size * 0.08)

            if !filled {
                VStack {
                    Spacer()
                    Capsule()
                        .fill(color)
                        .frame(width: size * 0.6, height: max(2, 3 * fontScale))
                        .padding(.bottom, size * 0.07)
                }
            }

            if isFolder {
                folderTab
            }
        }
    }

    /// Die Lasche oben links. Sie ragt von oben in die Kachel; der obere Rand wird von der Kachelform abgeschnitten.
    private var folderTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Spacer().frame(width: size * 0.14)
                RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                    .fill(filled ? Color.white.opacity(0.4) : color)
                    .frame(width: size * 0.34, height: max(6, size * 0.1) + size * 0.05)
                    .offset(y: -size * 0.05)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Die Zurück-Kachel: erster Platz im Raster einer geöffneten Ordnerseite, hellgrau mit großem „<“.
struct BackTileView: View {
    let size: CGFloat
    var dropTarget = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.19, style: .continuous)
                .fill(Color(hex: 0xD0D3DA))
            Text("<")
                .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: 0x1E1F23))
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.19, style: .continuous)
                .stroke(Theme.dropTarget, lineWidth: dropTarget ? 3 : 0)
        )
        .scaleEffect(dropTarget ? 1.06 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Zurück zur Hauptebene"))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Vorschau des Geräts

/// Zeigt das Pad so, wie es auf dem gewählten Gerät erscheint: gleiche Spaltenzahl, gleiche Mindestgröße.
/// Ist ein Ordner geöffnet, steht die Zurück-Kachel an erster Stelle.
/// Einträge lassen sich anklicken (auswählen), ziehen (neu anordnen, in einen Ordner legen) und Ordner per Doppelklick öffnen.
struct PadPreview: View {
    let set: PadSet
    /// Der geöffnete Ordner, nil auf der Hauptebene.
    let folder: PadFolder?
    let device: PadDevice
    @Binding var selectedID: UUID?
    let isConnected: Bool
    let onOpen: (UUID) -> Void
    let onBack: () -> Void
    /// Gezogener Eintrag nimmt den Platz des Ziels ein (gleiche Ebene).
    let onReorder: (UUID, UUID) -> Void
    /// Button wird in einen Ordner gelegt (Hauptebene → Ordner).
    let onDropInto: (UUID, UUID) -> Void
    /// Button aus einem Ordner wird auf die Hauptebene gelegt (auf die Zurück-Kachel gezogen).
    let onDropToTop: (UUID) -> Void
    let onAdd: () -> Void

    @State private var dragging: UUID? = nil
    @State private var hoverFolder: UUID? = nil
    @State private var hoverBack = false

    private var visibleItems: [PadItem] {
        if let folder = folder {
            return folder.buttons.map { PadItem.button($0) }
        }
        return set.items
    }

    var body: some View {
        GeometryReader { proxy in
            screen(in: proxy.size)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func screen(in available: CGSize) -> some View {
        let scale = max(0.2, min((available.width - 24) / CGFloat(device.width), (available.height - 24) / CGFloat(device.height)))
        let width = CGFloat(device.width) * scale
        let height = CGFloat(device.height) * scale
        let columns = device.columns(minTile: set.size.minTile(tablet: device.isTablet))
        let tile = CGFloat(device.tileSize(columns: columns)) * scale
        let gap = CGFloat(device.gap) * scale
        let padding = CGFloat(device.sidePadding) * scale
        let fontScale = max(scale, 0.75)
        let gridColumns = Array(repeating: GridItem(.fixed(tile), spacing: gap), count: columns)

        return VStack(spacing: 0) {
            header(fontScale: fontScale, padding: padding, scale: scale)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gap) {
                    if folder != nil {
                        backTile(tile: tile)
                    }
                    ForEach(visibleItems) { item in
                        itemView(item, tile: tile, fontScale: fontScale)
                    }
                    addCell(tile: tile)
                }
                .padding(.horizontal, padding)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .background(Theme.padBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Theme.bezel))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Theme.fieldLine, lineWidth: 1))
        .onDrop(of: [UTType.text], isTargeted: nil) { _ in
            resetDrag()
            return true
        }
    }

    private func header(fontScale: CGFloat, padding: CGFloat, scale: CGFloat) -> some View {
        HStack(spacing: 6) {
            if let folder = folder {
                Text(set.name)
                    .font(.system(size: 12 * fontScale))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
                Text("›")
                    .font(.system(size: 12 * fontScale))
                    .foregroundColor(Theme.muted)
                Circle().fill(folder.color.color).frame(width: 8, height: 8)
                Text(folder.name)
                    .font(.system(size: 13 * fontScale, weight: .bold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
            } else {
                Circle().fill(set.color.color).frame(width: 8, height: 8)
                Text(set.name)
                    .font(.system(size: 13 * fontScale, weight: .bold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
            }
            Spacer()
            Circle().fill(isConnected ? Theme.live : Theme.muted).frame(width: 6, height: 6)
            Text(isConnected ? "Mac verbunden" : "Vorschau")
                .font(.system(size: 10 * fontScale))
                .foregroundColor(Theme.muted)
        }
        .padding(.horizontal, padding)
        .padding(.top, max(10, 22 * scale))
        .padding(.bottom, 8)
    }

    // MARK: Kacheln

    private func isTopButton(_ id: UUID) -> Bool {
        for item in set.items {
            if case .button(let button) = item, button.id == id { return true }
        }
        return false
    }

    private func resetDrag() {
        dragging = nil
        hoverFolder = nil
        hoverBack = false
    }

    @ViewBuilder
    private func itemView(_ item: PadItem, tile: CGFloat, fontScale: CGFloat) -> some View {
        switch item {
        case .button(let button):
            interactive(
                PadTileView(
                    label: button.label,
                    keys: button.shortcut.displayString,
                    color: set.color(for: button).color,
                    filled: set.isFilled(button),
                    showKeys: set.showShortcuts,
                    size: tile,
                    fontScale: fontScale,
                    selected: selectedID == button.id
                ),
                id: button.id,
                isFolder: false,
                description: "\(button.label), \(button.shortcut.displayString)"
            )
        case .folder(let folder):
            interactive(
                PadTileView(
                    label: folder.name,
                    keys: folder.buttons.count == 1 ? "1 Button" : "\(folder.buttons.count) Buttons",
                    color: folder.color.color,
                    filled: set.isFilled(folder),
                    showKeys: true,
                    size: tile,
                    fontScale: fontScale,
                    selected: selectedID == folder.id,
                    isFolder: true,
                    dropTarget: hoverFolder == folder.id
                ),
                id: folder.id,
                isFolder: true,
                description: "Ordner \(folder.name), \(folder.buttons.count) Buttons"
            )
        }
    }

    private func interactive<Content: View>(_ content: Content, id: UUID, isFolder: Bool, description: String) -> some View {
        content
            .opacity(dragging == id ? 0.35 : 1)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    if isFolder { onOpen(id) }
                }
            )
            .onTapGesture { selectedID = id }
            .onDrag {
                dragging = id
                return NSItemProvider(object: id.uuidString as NSString)
            }
            .onDrop(of: [UTType.text], delegate: TileDropDelegate(
                onEnter: { dragEntered(target: id, isFolder: isFolder) },
                onExit: { if hoverFolder == id { hoverFolder = nil } },
                onDrop: { dropped(on: id, isFolder: isFolder) }
            ))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(description))
            .accessibilityAddTraits(.isButton)
    }

    private func dragEntered(target: UUID, isFolder: Bool) {
        guard let source = dragging, source != target else { return }
        if isFolder && folder == nil && isTopButton(source) {
            // Ein Button über einem Ordner: wird beim Loslassen dort abgelegt.
            hoverFolder = target
            return
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            onReorder(source, target)
        }
    }

    private func dropped(on target: UUID, isFolder: Bool) -> Bool {
        if let source = dragging, isFolder, hoverFolder == target, isTopButton(source) {
            onDropInto(source, target)
        }
        resetDrag()
        return true
    }

    private func backTile(tile: CGFloat) -> some View {
        BackTileView(size: tile, dropTarget: hoverBack)
            .contentShape(Rectangle())
            .onTapGesture { onBack() }
            .onDrop(of: [UTType.text], delegate: TileDropDelegate(
                onEnter: { if dragging != nil { hoverBack = true } },
                onExit: { hoverBack = false },
                onDrop: {
                    if let source = dragging {
                        onDropToTop(source)
                    }
                    resetDrag()
                    return true
                }
            ))
    }

    private func addCell(tile: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: tile * 0.19, style: .continuous)
            .stroke(Theme.fieldLine, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .frame(width: tile, height: tile)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: max(12, tile * 0.28), weight: .semibold))
                    .foregroundColor(Theme.muted)
            )
            .contentShape(Rectangle())
            .onTapGesture { onAdd() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Button hinzufügen"))
            .accessibilityAddTraits(.isButton)
    }
}

/// Reicht die Ereignisse beim Ziehen an die Vorschau weiter.
struct TileDropDelegate: DropDelegate {
    let onEnter: () -> Void
    let onExit: () -> Void
    let onDrop: () -> Bool

    func dropEntered(info: DropInfo) {
        onEnter()
    }

    func dropExited(info: DropInfo) {
        onExit()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        onDrop()
    }
}
