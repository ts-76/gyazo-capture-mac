import CoreGraphics

enum AnnotationFrameTransformer {
    static func unitPoint(for point: CGPoint, in frame: CGRect) -> CGPoint {
        guard frame.width > 0, frame.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return clampUnitPoint(
            CGPoint(
                x: (point.x - frame.minX) / frame.width,
                y: (point.y - frame.minY) / frame.height
            )
        )
    }

    static func point(from unitPoint: CGPoint, in frame: CGRect) -> CGPoint {
        let unit = clampUnitPoint(unitPoint)
        return CGPoint(
            x: frame.minX + unit.x * frame.width,
            y: frame.minY + unit.y * frame.height
        )
    }

    static func clampUnitPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
    }

    static func rotateUnitPoint(_ point: CGPoint, clockwise: Bool) -> CGPoint {
        let unit = clampUnitPoint(point)
        if clockwise {
            return CGPoint(x: 1 - unit.y, y: unit.x)
        }
        return CGPoint(x: unit.y, y: 1 - unit.x)
    }

    static func lineEndpoints(_ annotation: AnnotationItem) -> (CGPoint, CGPoint) {
        (
            point(from: annotation.startUnitPoint, in: annotation.frame),
            point(from: annotation.endUnitPoint, in: annotation.frame)
        )
    }

    static func clampedFrame(
        _ frame: CGRect,
        within imageSize: CGSize,
        minimumSize: CGFloat = 1
    ) -> CGRect {
        let width = min(max(frame.width, minimumSize), imageSize.width)
        let height = min(max(frame.height, minimumSize), imageSize.height)
        let maxX = max(0, imageSize.width - width)
        let maxY = max(0, imageSize.height - height)
        return CGRect(
            x: min(max(frame.minX, 0), maxX),
            y: min(max(frame.minY, 0), maxY),
            width: width,
            height: height
        )
    }

    static func rotatedFrame(
        _ frame: CGRect,
        sourceImageSize: CGSize,
        clockwise: Bool
    ) -> CGRect {
        if clockwise {
            return CGRect(
                x: sourceImageSize.height - frame.maxY,
                y: frame.minX,
                width: frame.height,
                height: frame.width
            )
        } else {
            return CGRect(
                x: frame.minY,
                y: sourceImageSize.width - frame.maxX,
                width: frame.height,
                height: frame.width
            )
        }
    }

    static func clampedRotatedFrame(
        _ frame: CGRect,
        sourceImageSize: CGSize,
        destinationImageSize: CGSize,
        clockwise: Bool
    ) -> CGRect {
        let rotated = rotatedFrame(
            frame,
            sourceImageSize: sourceImageSize,
            clockwise: clockwise
        )
        return clampedFrame(rotated, within: destinationImageSize, minimumSize: 1)
    }

    static func frameAfterCrop(_ frame: CGRect, cropRect: CGRect) -> CGRect? {
        let intersection = frame.intersection(cropRect)
        guard !intersection.isNull && intersection.width > 0 && intersection.height > 0 else { return nil }
        return CGRect(
            x: frame.minX - cropRect.minX,
            y: frame.minY - cropRect.minY,
            width: frame.width,
            height: frame.height
        )
    }

    static func rotatedImageSize(afterRotating imageSize: CGSize) -> CGSize {
        CGSize(width: imageSize.height, height: imageSize.width)
    }
}
