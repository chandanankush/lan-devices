import AppKit
import Foundation

@main
struct LDCIconExporter {
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var images: [[String: String]] = []
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
                let bitmap = LDCIconGenerator.bitmap(pixels: points * scale)
                guard let data = bitmap.representation(using: .png, properties: [:]) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                try data.write(to: output.appendingPathComponent(filename))
                images.append(["filename": filename, "idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x"])
            }
        }
        let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
        let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent("Contents.json"))
        print("Generated all 10 macOS AppIcon assets at \(output.path)")
    }
}
