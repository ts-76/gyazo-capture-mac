import AppKit
import CoreImage
import Foundation
import CoreGraphics

enum ImageTransformError: LocalizedError {
    case emptySourceImage
    case missingSourceCGImage
    case imageConversionFailed
    case invalidCropRect

    var errorDescription: String? {
        switch self {
        case .emptySourceImage:
            return "元画像が無効です。"
        case .missingSourceCGImage:
            return "元画像を変換できませんでした。"
        case .imageConversionFailed:
            return "画像変換に失敗しました。"
        case .invalidCropRect:
            return "クロップ範囲を作成できませんでした。"
        }
    }
}

enum ImageTransformService {
    private static let context = CIContext(options: [.useSoftwareRenderer: true])

    static func rotatedImage(_ image: NSImage, clockwise: Bool) throws -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageTransformError.missingSourceCGImage
        }

        let inputImage = CIImage(cgImage: cgImage)
        let oriented = clockwise
            ? inputImage.oriented(.right)
            : inputImage.oriented(.left)
        let extent = oriented.extent.integral
        guard extent.width >= 1, extent.height >= 1 else { throw ImageTransformError.emptySourceImage }

        guard let rendered = context.createCGImage(oriented, from: extent) else {
            throw ImageTransformError.imageConversionFailed
        }

        return NSImage(
            cgImage: rendered,
            size: NSSize(width: extent.width, height: extent.height)
        )
    }

    static func croppedImage(_ image: NSImage, to cropRect: CGRect) throws -> NSImage {
        guard cropRect.width >= 1 && cropRect.height >= 1 else {
            throw ImageTransformError.invalidCropRect
        }
        guard let sourceCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageTransformError.missingSourceCGImage
        }

        let imageBounds = CGRect(
            x: 0,
            y: 0,
            width: sourceCGImage.width,
            height: sourceCGImage.height
        )
        let convertedRect = cropRect.integral.intersection(imageBounds)
        guard convertedRect.width >= 1, convertedRect.height >= 1 else {
            throw ImageTransformError.invalidCropRect
        }

        guard let cropped = sourceCGImage.cropping(to: convertedRect) else {
            throw ImageTransformError.imageConversionFailed
        }

        return NSImage(
            cgImage: cropped,
            size: NSSize(width: cropped.width, height: cropped.height)
        )
    }
}
