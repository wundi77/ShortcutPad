import SwiftUI

struct HelperView: View {
    @EnvironmentObject private var controller: HelperController

    var body: some View {
        ScrollView {
            content
        }
        .frame(minWidth: 540, minHeight: 600)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ShortcutPad Helper")
                .font(.title2.weight(.bold))

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

            webBox

            GroupBox(label: Text("Berechtigung „Bedienungshilfen“")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(controller.accessibilityGranted ? "✓ Freigegeben" : "✗ Nicht freigegeben – ohne sie kann der Helper keine Tasten senden.")
                        .foregroundColor(controller.accessibilityGranted ? .green : .red)
                    if !controller.accessibilityGranted {
                        HStack {
                            Button("Berechtigung anfragen") { controller.requestAccessibility() }
                            Button("Systemeinstellungen öffnen") { controller.openAccessibilitySettings() }
                        }
                        Text("Falls es nach dem Freigeben weiter „nicht freigegeben“ zeigt: Helper beenden und neu starten.")
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

    private var webBox: some View {
        GroupBox(label: Text("Webseite für iPad und iPhone (gleiches WLAN/LAN)")) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Webseite im lokalen Netzwerk anbieten", isOn: $controller.webEnabled)

                if let error = controller.webError {
                    Text("✗ Webserver konnte nicht starten: \(error)")
                        .foregroundColor(.red)
                }

                if controller.webRunning {
                    if controller.webAddresses.isEmpty {
                        Text("Keine Netzwerkadresse gefunden – ist der Mac mit WLAN oder LAN verbunden?")
                            .foregroundColor(.orange)
                    } else {
                        HStack(alignment: .top, spacing: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Im Safari des iPads öffnen:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(controller.webAddresses, id: \.self) { ip in
                                    Text(controller.webURL(for: ip))
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                Text("Kopplungscode")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                                Text(controller.webPIN)
                                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                    .textSelection(.enabled)
                                row("Gekoppelte Geräte", "\(controller.webPairedCount)")
                                Button("Kopplungen löschen, neuen Code erzeugen") {
                                    controller.resetWebPairings()
                                }
                            }
                            if let text = controller.webQRText, let image = QRCode.image(for: text) {
                                VStack(spacing: 4) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .interpolation(.none)
                                        .frame(width: 140, height: 140)
                                        .padding(6)
                                        .background(Color.white)
                                    Text("QR-Code mit der iPad-Kamera scannen\n(koppelt automatisch)")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                Text("Hinweis: Die Verbindung ist unverschlüsselt (HTTP) und nur durch den Kopplungscode geschützt. Nur in einem vertrauenswürdigen Netz verwenden. Der Mac darf nicht schlafen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
        }
    }
}
