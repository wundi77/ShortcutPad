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
}

// MARK: - Ein Button des Pads

/// Zeichnet einen Pad-Button wie im Design: Text, Kürzel klein darunter, Farbe als Balken oder Vollfläche.
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.19, style: .continuous)
                .fill(filled ? color : Theme.tile)

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
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.19 + 3, style: .continuous)
                .stroke(Color.white, lineWidth: selected ? 2 : 0)
                .padding(-4)
        )
    }
}

// MARK: - Vorschau des Geräts

/// Zeigt das Pad so, wie es auf dem gewählten Gerät erscheint: gleiche Spaltenzahl, gleiche Mindestgröße.
/// Buttons lassen sich anklicken (auswählen) und ziehen (neu anordnen).
struct PadPreview: View {
    let set: PadSet
    let device: PadDevice
    @Binding var selectedID: UUID?
    let isConnected: Bool
    let onMove: (UUID, UUID) -> Void
    let onAdd: () -> Void

    @State private var dragging: UUID? = nil

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
            HStack(spacing: 6) {
                Circle().fill(set.color.color).frame(width: 8, height: 8)
                Text(set.name)
                    .font(.system(size: 13 * fontScale, weight: .bold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Spacer()
                Circle().fill(isConnected ? Theme.live : Theme.muted).frame(width: 6, height: 6)
                Text(isConnected ? "Mac verbunden" : "Vorschau")
                    .font(.system(size: 10 * fontScale))
                    .foregroundColor(Theme.muted)
            }
            .padding(.horizontal, padding)
            .padding(.top, max(10, 22 * scale))
            .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gap) {
                    ForEach(set.buttons) { button in
                        tileView(button, tile: tile, fontScale: fontScale)
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
            dragging = nil
            return true
        }
    }

    private func tileView(_ button: PadButton, tile: CGFloat, fontScale: CGFloat) -> some View {
        PadTileView(
            label: button.label,
            keys: button.shortcut.displayString,
            color: set.color(for: button).color,
            filled: set.isFilled(button),
            showKeys: set.showShortcuts,
            size: tile,
            fontScale: fontScale,
            selected: selectedID == button.id
        )
        .opacity(dragging == button.id ? 0.35 : 1)
        .contentShape(Rectangle())
        .onTapGesture { selectedID = button.id }
        .onDrag {
            dragging = button.id
            return NSItemProvider(object: button.id.uuidString as NSString)
        }
        .onDrop(of: [UTType.text], delegate: TileDropDelegate(targetID: button.id, dragging: $dragging, onMove: onMove))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(button.label), \(button.shortcut.displayString)"))
        .accessibilityAddTraits(.isButton)
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

/// Ordnet beim Ziehen sofort um, sobald der gezogene Button über einem anderen schwebt.
struct TileDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var dragging: UUID?
    let onMove: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let source = dragging, source != targetID else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            onMove(source, targetID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
