import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum MaskEffectRendererError: LocalizedError {
    case unreadableImage
    case unsupportedEffect
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "マスク処理用の画像を読み取れませんでした。"
        case .unsupportedEffect: return "対応していないマスク処理です。"
        case .renderingFailed: return "ブラーまたはモザイクを描画できませんでした。"
        }
    }
}

enum MaskEffectRenderer {
    private static let context = CIContext(options: [.cacheIntermediates: true])

    static func filteredImage(
        baseImage: NSImage,
        kind: AnnotationKind,
        strength: CGFloat
    ) throws -> NSImage {
        let source = try sourceImage(from: baseImage)
        let filtered = try filteredImage(source, kind: kind, strength: strength)
        return try renderedImage(from: filtered, extent: source.extent)
    }

    static func applyingMasks(
        to baseImage: NSImage,
        annotations: [AnnotationItem]
    ) throws -> NSImage {
        let masks = annotations.filter { $0.kind.isMask }
        guard !masks.isEmpty else { return baseImage }

        let source = try sourceImage(from: baseImage)
        var result = source

        for mask in masks {
            let filtered = try filteredImage(
                source,
                kind: mask.kind,
                strength: mask.effectStrength
            )
            let region = coreImageRect(
                fromTopLeftRect: mask.frame,
                imageHeight: source.extent.height
            ).intersection(source.extent)
            guard !region.isEmpty else { continue }

            result = filtered
                .cropped(to: region)
                .composited(over: result)
                .cropped(to: source.extent)
        }

        return try renderedImage(from: result, extent: source.extent)
    }

    private static func filteredImage(
        _ source: CIImage,
        kind: AnnotationKind,
        strength: CGFloat
    ) throws -> CIImage {
        switch kind {
        case .blur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = source.clampedToExtent()
            filter.radius = Float(max(1, strength))
            guard let output = filter.outputImage else {
                throw MaskEffectRendererError.renderingFailed
            }
            return output.cropped(to: source.extent)

        case .mosaic:
            let filter = CIFilter.pixellate()
            filter.inputImage = source
            filter.scale = Float(max(2, strength))
            filter.center = CGPoint(x: source.extent.minX, y: source.extent.minY)
            guard let output = filter.outputImage else {
                throw MaskEffectRendererError.renderingFailed
            }
            return output.cropped(to: source.extent)

        case .rectangle, .text, .line, .arrow, .highlight, .ellipse, .redaction:
            throw MaskEffectRendererError.unsupportedEffect
        }
    }

    private static func sourceImage(from image: NSImage) throws -> CIImage {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else {
            throw MaskEffectRendererError.unreadableImage
        }
        return CIImage(cgImage: cgImage)
    }

    private static func renderedImage(from image: CIImage, extent: CGRect) throws -> NSImage {
        guard let cgImage = context.createCGImage(image, from: extent) else {
            throw MaskEffectRendererError.renderingFailed
        }
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: extent.width, height: extent.height)
        )
    }

    private static func coreImageRect(fromTopLeftRect rect: CGRect, imageHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: imageHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}
