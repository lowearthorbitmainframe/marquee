// Renders an SVG to PNG with WebKit, so filters and blend modes come out as a browser draws them.
// usage: swift render.swift in.svg out.png width height
import AppKit
import WebKit

let args = CommandLine.arguments
let input = URL(fileURLWithPath: args[1]), output = URL(fileURLWithPath: args[2])
let width = CGFloat(Double(args[3])!), height = CGFloat(Double(args[4])!)

final class Renderer: NSObject, WKNavigationDelegate {
    let view = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height))
    func start() {
        view.navigationDelegate = self
        view.loadFileURL(input, allowingReadAccessTo: input.deletingLastPathComponent())
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let config = WKSnapshotConfiguration()
            config.rect = NSRect(x: 0, y: 0, width: width, height: height)
            config.snapshotWidth = NSNumber(value: Double(width))
            webView.takeSnapshot(with: config) { image, error in
                guard let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else { print(error ?? "no image"); exit(1) }
                try! png.write(to: output)
                exit(0)
            }
        }
    }
}

let app = NSApplication.shared
let renderer = Renderer()
renderer.start()
app.run()
