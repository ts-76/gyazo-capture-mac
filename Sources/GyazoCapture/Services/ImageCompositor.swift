import AppKit
import CoreText
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
        let pixelAlignedImage = pixelAlignedImage(maskedImage, pixelSize: pixelSize)
        let rendered = NSImage(size: pixelSize, flipped: false) { rect in
            pixelAlignedImage.draw(in: rect, from: .zero, operation: .copy, fraction: 1)

            for annotation in annotations where !annotation.kind.isMask {
                let color = NSColor(hex: annotation.colorHex) ?? .systemRed
                let outputFrame = bottomLeftFrame(
                    fromTopLeftFrame: annotation.frame,
                    imageHeight: pixelSize.height
                )
                switch annotation.kind {
                case .rectangle:
                    color.setStroke()
                    let path = NSBezierPath(rect: outputFrame)
                    path.lineWidth = annotation.lineWidth
                    path.stroke()
                case .line:
                    let lineEndpoints = AnnotationFrameTransformer.lineEndpoints(annotation)
                    let path = NSBezierPath()
                    path.move(to: bottomLeftPoint(fromTopLeftPoint: lineEndpoints.0, imageHeight: pixelSize.height))
                    path.line(to: bottomLeftPoint(fromTopLeftPoint: lineEndpoints.1, imageHeight: pixelSize.height))
                    path.lineWidth = annotation.lineWidth
                    path.lineCapStyle = .round
                    color.setStroke()
                    path.stroke()
                case .arrow:
                    let arrowEndpoints = AnnotationFrameTransformer.lineEndpoints(annotation)
                    let start = bottomLeftPoint(
                        fromTopLeftPoint: arrowEndpoints.0,
                        imageHeight: pixelSize.height
                    )
                    let end = bottomLeftPoint(
                        fromTopLeftPoint: arrowEndpoints.1,
                        imageHeight: pixelSize.height
                    )
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
                        roundedRect: outputFrame,
                        xRadius: min(outputFrame.width, outputFrame.height) * 0.12,
                        yRadius: min(outputFrame.width, outputFrame.height) * 0.12
                    )
                    path.fill()
                case .ellipse:
                    color.setStroke()
                    let path = NSBezierPath(ovalIn: outputFrame)
                    path.lineWidth = annotation.lineWidth
                    path.stroke()
                case .redaction:
                    color.setFill()
                    NSBezierPath(rect: outputFrame).fill()
                case .text:
                    drawText(annotation, color: color, in: outputFrame)
                case .magnifier:
                    drawMagnifier(
                        annotation,
                        sourceImage: pixelAlignedImage,
                        imageHeight: pixelSize.height,
                        color: color
                    )
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

    private static func pixelAlignedImage(_ image: NSImage, pixelSize: CGSize) -> NSImage {
        NSImage(size: pixelSize, flipped: false) { rect in
            image.draw(
                in: rect,
                from: .zero,
                operation: .copy,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return true
        }
    }

    private static func bottomLeftFrame(
        fromTopLeftFrame frame: CGRect,
        imageHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: frame.minX,
            y: imageHeight - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    private static func bottomLeftPoint(
        fromTopLeftPoint point: CGPoint,
        imageHeight: CGFloat
    ) -> CGPoint {
        CGPoint(x: point.x, y: imageHeight - point.y)
    }

    private static func drawText(
        _ annotation: AnnotationItem,
        color: NSColor,
        in frame: CGRect
    ) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributedText = NSAttributedString(
            string: annotation.text,
            attributes: [
                .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
        let textFrame = frame.insetBy(dx: 4, dy: 2)
        guard textFrame.width > 0, textFrame.height > 0 else { return }
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let path = CGPath(rect: textFrame, transform: nil)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributedText.length),
            path,
            nil
        )
        CTFrameDraw(frame, context)
    }

    private static func drawMagnifier(
        _ annotation: AnnotationItem,
        sourceImage: NSImage,
        imageHeight: CGFloat,
        color: NSColor
    ) {
        let sourceFrame = bottomLeftFrame(
            fromTopLeftFrame: annotation.frame,
            imageHeight: imageHeight
        )
        let destinationFrame = bottomLeftFrame(
            fromTopLeftFrame: MagnifierGeometry.destinationFrame(for: annotation),
            imageHeight: imageHeight
        )
        let connector = magnifierConnectorEndpoints(
            sourceFrame: sourceFrame,
            destinationFrame: destinationFrame
        )
        let connectorPath = NSBezierPath()
        connectorPath.move(to: connector.0)
        connectorPath.line(to: connector.1)
        connectorPath.lineCapStyle = .round
        stroke(connectorPath, color: .white, width: annotation.lineWidth + 4)
        stroke(connectorPath, color: color, width: annotation.lineWidth)

        let sourceOutline = NSBezierPath(ovalIn: sourceFrame)
        sourceOutline.setLineDash([6, 4], count: 2, phase: 0)
        stroke(sourceOutline, color: .white, width: annotation.lineWidth + 3)
        stroke(sourceOutline, color: color, width: annotation.lineWidth)

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: destinationFrame).addClip()
        sourceImage.draw(
            in: destinationFrame,
            from: sourceFrame,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()

        let destinationOutline = NSBezierPath(ovalIn: destinationFrame)
        stroke(destinationOutline, color: .white, width: annotation.lineWidth + 5)
        stroke(destinationOutline, color: color, width: annotation.lineWidth)
    }

    private static func magnifierConnectorEndpoints(
        sourceFrame: CGRect,
        destinationFrame: CGRect
    ) -> (CGPoint, CGPoint) {
        let dx = destinationFrame.midX - sourceFrame.midX
        let dy = destinationFrame.midY - sourceFrame.midY
        let length = max(1, hypot(dx, dy))
        let unit = CGPoint(x: dx / length, y: dy / length)
        return (
            CGPoint(
                x: sourceFrame.midX + unit.x * sourceFrame.width / 2,
                y: sourceFrame.midY + unit.y * sourceFrame.height / 2
            ),
            CGPoint(
                x: destinationFrame.midX - unit.x * destinationFrame.width / 2,
                y: destinationFrame.midY - unit.y * destinationFrame.height / 2
            )
        )
    }

    private static func stroke(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
        color.setStroke()
        path.lineWidth = width
        path.stroke()
    }
}
