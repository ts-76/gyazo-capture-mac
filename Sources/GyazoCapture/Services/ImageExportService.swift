import AppKit
import Foundation

enum ImageExportError: LocalizedError {
    case emptyImageData
    case clipboardWriteFailed

    var errorDescription: String? {
        switch self {
        case .emptyImageData:
            return "保存またはコピー対象の画像データが空です。"
        case .clipboardWriteFailed:
            return "クリップボードに画像を書き込めませんでした。"
        }
    }
}

enum ImageExportService {
    static func defaultPNGFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "capture_\(formatter.string(from: date)).png"
    }

    static func normalizedPNGFileName(_ proposedName: String) -> String {
        let forbidden = CharacterSet.controlCharacters.union(
            CharacterSet(charactersIn: "/:\\\"\n\r\t")
        )
        var name = proposedName
            .components(separatedBy: forbidden)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))

        if name.lowercased().hasSuffix(".png") {
            name.removeLast(4)
        }
        name = String(name.prefix(120))
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if name.isEmpty {
            name = "capture"
        }
        return "\(name).png"
    }

    static func renderPNG(baseImage: NSImage, annotations: [AnnotationItem]) throws -> Data {
        try ImageCompositor.pngData(baseImage: baseImage, annotations: annotations)
    }

    static func copyPNGToClipboard(_ pngData: Data) throws {
        guard let image = NSImage(data: pngData) else {
            throw ImageExportError.emptyImageData
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.tiff, .png], owner: nil)
        guard pasteboard.setData(pngData, forType: .png) else {
            throw ImageExportError.clipboardWriteFailed
        }
        pasteboard.writeObjects([image])
    }
}
