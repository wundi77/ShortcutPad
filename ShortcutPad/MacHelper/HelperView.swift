import SwiftUI

/// Fenster „Verbindung und Kopplung“: Oben stehen QR-Code und Kopplungscode, darunter Status, Berechtigung und Protokoll.
struct HelperView: View {
    @EnvironmentObject private var controller: HelperController

    var body: some View {
        ScrollView {
            content
        }
        .frame(minWidth: 640, minHeight: 620)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            pairingCard

            GroupBox(label: Text("Status")) {
                VStack(alignment: .leading, spacing: 6) {
                    row("Webseite", controller.webRunning ? "wird angeboten" : "aus")
                    row("Gekoppelte Geräte", "\(controller.webPairedCount)")
                    row("Seite verbunden", controller.webClientActive ? "ja" : "nein")
                    row("Aktives Programm", controller.frontmostApp)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox(label: Text("Berechtigung „Bedienungshilfen“")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(controller.accessibilityGranted ? "✓ Freigegeben" : "✗ Nicht freigegeben – ohne sie kann die App keine Tasten senden.")
                        .foregroundColor(controller.accessibilityGranted ? .green : .red)
                    if !controller.accessibilityGranted {
                        HStack {
                            Button("Berechtigung anfragen") { controller.requestAccessibility() }
                            Button("Systemeinstellungen öffnen") { controller.openAccessibilitySettings() }
                        }
                        Text("Falls es nach dem Freigeben weiter „nicht freigegeben“ zeigt: App beenden und neu starten.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox(label: Text("Letzter Befehl von der Webseite")) {
                Text(controller.lastTrigger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            }

            GroupBox(label: Text("Selbsttest")) {
                VStack(alignment: .leading, spacing: 6) {
                    row("Letzte Taste hier", controller.lastLocalKey)
                    Toggle("Tasten in diesem Fenster abfangen (kein Piepton, ⌘Q etc. gesperrt)", isOn: $controller.captureLocalKeys)
                    Text("So testest du: dieses Fenster anklicken, dann auf der Webseite einen Button tippen – das Kürzel erscheint oben. Für den echten Test stattdessen in ein anderes Programm klicken (z. B. TextEdit).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox(label: Text("Protokoll")) {
                ScrollView {
                    Text(controller.logLines.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 130)
            }
        }
        .padding(18)
    }

    // MARK: Kopplung

    private var pairingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Mit iPad oder iPhone koppeln")
                    .font(.title2.weight(.bold))
                Spacer()
                Toggle("Webseite anbieten", isOn: $controller.webEnabled)
                    .toggleStyle(.switch)
            }

            if let error = controller.webError {
                Text("✗ Der Webserver konnte nicht starten: \(error)")
                    .foregroundColor(.red)
            }

            if !controller.webRunning {
                Text("Schalte „Webseite anbieten“ ein. Dann erscheinen hier der QR-Code und der Kopplungscode.")
                    .foregroundColor(.secondary)
            } else if controller.webAddresses.isEmpty {
                Text("Keine Netzwerkadresse gefunden. Ist der Mac mit WLAN oder LAN verbunden?")
                    .foregroundColor(.orange)
            } else {
                HStack(alignment: .top, spacing: 26) {
                    qrBlock
                    VStack(alignment: .leading, spacing: 14) {
                        codeBlock
                        addressBlock
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Text("Mac und Gerät müssen im selben WLAN sein. Die Verbindung ist unverschlüsselt (HTTP) und nur durch den Kopplungscode geschützt; nur in einem Netz verwenden, dem du vertraust. Der Mac darf nicht schlafen.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var qrBlock: some View {
        VStack(spacing: 8) {
            if let text = controller.webQRText, let image = QRCode.image(for: text) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 210, height: 210)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("Kamera am iPad oder iPhone auf den\nQR-Code richten und den Link antippen.\nDie Kopplung läuft dann automatisch.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var codeBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Kopplungscode")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(formattedPIN)
                .font(.system(size: 42, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)
            HStack(spacing: 10) {
                Text(controller.webPairedCount == 1 ? "1 Gerät gekoppelt" : "\(controller.webPairedCount) Geräte gekoppelt")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Button("Kopplungen löschen, neuen Code erzeugen") {
                    controller.resetWebPairings()
                }
                .controlSize(.small)
            }
        }
    }

    private var addressBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ohne QR-Code: im Safari öffnen und den Code eingeben")
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(controller.webAddresses, id: \.self) { ip in
                Text(controller.webURL(for: ip))
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            if controller.webAddresses.count > 1 {
                Text("Der QR-Code nutzt die erste Adresse. Erreicht das Gerät sie nicht, probiere eine der anderen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var formattedPIN: String {
        let pin = controller.webPIN
        guard pin.count == 6 else { return pin }
        return String(pin.prefix(3)) + " " + String(pin.suffix(3))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(value)
        }
    }
}
