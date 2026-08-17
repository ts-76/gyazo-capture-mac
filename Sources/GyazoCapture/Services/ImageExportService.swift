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
