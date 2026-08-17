import AppKit
import Foundation

enum ImageCompositorError: LocalizedError {
    case unreadableImage
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "元画像を読み取れませんでした。"
        case .pngEncodingFailed: return "編集後のPNGを作成できませんでした。"
        }
    }
}

enum ImageCompositor {
    static func pixelSize(of image: NSImage) throws -> CGSize {
        guard let data = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: data) else {
            throw ImageCompositorError.unreadableImage
        }
        return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }

    static func pngData(baseImage: NSImage, annotations: [AnnotationItem]) throws -> Data {
        let pixelSize = try pixelSize(of: baseImage)
        let maskedImage = try MaskEffectRenderer.applyingMasks(
            to: baseImage,
            annotations: annotations
        )
        let rendered = NSImage(size: pixelSize, flipped: true) { rect in
            maskedImage.draw(in: rect, from: .zero, operation: .copy, fraction: 1)

            for annotation in annotations where !annotation.kind.isMask {
                let color = NSColor(hex: annotation.colorHex) ?? .systemRed
                switch annotation.kind {
                case .rectangle:
                    color.setStroke()
                    let path = NSBezierPath(rect: annotation.frame)
                    path.lineWidth = annotation.lineWidth
                    path.stroke()
                case .line:
                    let lineEndpoints = AnnotationFrameTransformer.lineEndpoints(annotation)
                    let path = NSBezierPath()
                    path.move(to: lineEndpoints.0)
                    path.line(to: lineEndpoints.1)
                    path.lineWidth = annotation.lineWidth
                    path.lineCapStyle = .round
                    color.setStroke()
                    path.stroke()
                case .arrow:
                    let arrowEndpoints = AnnotationFrameTransformer.lineEndpoints(annotation)
                    let start = arrowEndpoints.0
                    let end = arrowEndpoints.1
                    let vector = CGPoint(x: end.x - start.x, y: end.y - start.y)
                    let length = max(20, hypot(vector.x, vector.y))
                    let headLength = min(length * 0.35, 28)
                    let arrowAngle = CGFloat.pi / 6
                    let angle = atan2(vector.y, vector.x)

                    let line = NSBezierPath()
                    line.move(to: start)
                    line.line(to: end)
                    line.lineWidth = annotation.lineWidth
                    line.lineCapStyle = .round
                    color.setStroke()
                    line.stroke()

                    let head = NSBezierPath()
                    let rotatedLeft = CGPoint(
                        x: end.x - headLength * cos(angle - arrowAngle),
                        y: end.y - headLength * sin(angle - arrowAngle)
                    )
                    let rotatedRight = CGPoint(
                        x: end.x - headLength * cos(angle + arrowAngle),
                        y: end.y - headLength * sin(angle + arrowAngle)
                    )

                    head.move(to: rotatedLeft)
                    head.line(to: end)
                    head.line(to: rotatedRight)
                    head.lineWidth = annotation.lineWidth
                    head.lineCapStyle = .round
                    head.lineJoinStyle = .round
                    color.setStroke()
                    head.stroke()
                case .highlight:
                    color.withAlphaComponent(annotation.fillOpacity).setFill()
                    let path = NSBezierPath(
                        roundedRect: annotation.frame,
                        xRadius: min(annotation.frame.width, annotation.frame.height) * 0.12,
                        yRadius: min(annotation.frame.width, annotation.frame.height) * 0.12
                    )
                    path.fill()
                case .ellipse:
                    color.setStroke()
                    let path = NSBezierPath(ovalIn: annotation.frame)
                    path.lineWidth = annotation.lineWidth
                    path.stroke()
                case .redaction:
                    color.setFill()
                    NSBezierPath(rect: annotation.frame).fill()
                case .text:
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.lineBreakMode = .byWordWrapping
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold),
                        .foregroundColor: color,
                        .paragraphStyle: paragraph
                    ]
                    NSAttributedString(string: annotation.text, attributes: attributes)
                        .draw(in: annotation.frame.insetBy(dx: 4, dy: 2))
                case .blur, .mosaic:
                    break
                }
            }
            return true
        }

        guard let tiff = rendered.tiffRepresentation,
              let representation = NSBitmapImageRep(data: tiff),
              let png = representation.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            throw ImageCompositorError.pngEncodingFailed
        }
        return png
    }
}
