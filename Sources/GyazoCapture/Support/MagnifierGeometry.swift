import CoreGraphics

enum MagnifierGeometry {
    static let minimumSourceDiameter: CGFloat = 48
    static let defaultSourceDiameter: CGFloat = 120
    static let placementGap: CGFloat = 28

    static func circularSourceFrame(_ frame: CGRect, within imageSize: CGSize) -> CGRect {
        let maximumDiameter = max(
            minimumSourceDiameter,
            min(imageSize.width, imageSize.height) / 3.25
        )
        let requestedDiameter = max(frame.width, frame.height)
        let diameter = min(
            max(requestedDiameter, minimumSourceDiameter),
            maximumDiameter
        )
        return AnnotationFrameTransformer.clampedFrame(
            CGRect(x: frame.minX, y: frame.minY, width: diameter, height: diameter),
            within: imageSize,
            minimumSize: minimumSourceDiameter
        )
    }

    static func destinationFrame(for annotation: AnnotationItem) -> CGRect {
        let diameter = annotation.frame.width * max(1, annotation.magnification)
        let center = CGPoint(
            x: annotation.frame.midX + annotation.magnifierDestinationOffset.width,
            y: annotation.frame.midY + annotation.magnifierDestinationOffset.height
        )
        return CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
    }

    static func defaultDestinationOffset(
        sourceFrame: CGRect,
        magnification: CGFloat,
        imageSize: CGSize
    ) -> CGSize {
        let destinationDiameter = sourceFrame.width * max(1, magnification)
        let distance = sourceFrame.width / 2 + placementGap + destinationDiameter / 2
        let candidates = [
            CGSize(width: distance, height: 0),
            CGSize(width: -distance, height: 0),
            CGSize(width: 0, height: distance),
            CGSize(width: 0, height: -distance)
        ]
        if let fitting = candidates.first(where: {
            imageBounds(imageSize).contains(destinationFrame(
                sourceFrame: sourceFrame,
                offset: $0,
                magnification: magnification
            ))
        }) {
            return fitting
        }
        return clampedDestinationOffset(
            candidates[0],
            sourceFrame: sourceFrame,
            magnification: magnification,
            imageSize: imageSize
        )
    }

    static func clampedDestinationOffset(
        _ offset: CGSize,
        sourceFrame: CGRect,
        magnification: CGFloat,
        imageSize: CGSize
    ) -> CGSize {
        let proposed = destinationFrame(
            sourceFrame: sourceFrame,
            offset: offset,
            magnification: magnification
        )
        let maximumX = max(0, imageSize.width - proposed.width)
        let maximumY = max(0, imageSize.height - proposed.height)
        let clampedOrigin = CGPoint(
            x: min(max(proposed.minX, 0), maximumX),
            y: min(max(proposed.minY, 0), maximumY)
        )
        let clampedCenter = CGPoint(
            x: clampedOrigin.x + proposed.width / 2,
            y: clampedOrigin.y + proposed.height / 2
        )
        return CGSize(
            width: clampedCenter.x - sourceFrame.midX,
            height: clampedCenter.y - sourceFrame.midY
        )
    }

    static func rotatedOffset(_ offset: CGSize, clockwise: Bool) -> CGSize {
        clockwise
            ? CGSize(width: -offset.height, height: offset.width)
            : CGSize(width: offset.height, height: -offset.width)
    }

    private static func destinationFrame(
        sourceFrame: CGRect,
        offset: CGSize,
        magnification: CGFloat
    ) -> CGRect {
        let item = AnnotationItem(
            kind: .magnifier,
            frame: sourceFrame,
            magnification: magnification,
            magnifierDestinationOffset: offset
        )
        return destinationFrame(for: item)
    }

    private static func imageBounds(_ imageSize: CGSize) -> CGRect {
        CGRect(origin: .zero, size: imageSize)
    }
}
