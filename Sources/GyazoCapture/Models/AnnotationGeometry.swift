import Foundation

enum AnnotationGeometry {
    static func translatedFrame(
        from frame: CGRect,
        translation: CGSize,
        canvasScale: CGFloat
    ) -> CGRect {
        guard canvasScale > 0 else { return frame }
        return frame.offsetBy(
            dx: translation.width / canvasScale,
            dy: translation.height / canvasScale
        )
    }

    static func resizedFrame(
        from frame: CGRect,
        translation: CGSize,
        canvasScale: CGFloat
    ) -> CGRect {
        guard canvasScale > 0 else { return frame }
        return CGRect(
            x: frame.minX,
            y: frame.minY,
            width: frame.width + translation.width / canvasScale,
            height: frame.height + translation.height / canvasScale
        )
    }

    static func clampedFrame(
        _ frame: CGRect,
        within imageSize: CGSize,
        minimumSize: CGFloat = 20
    ) -> CGRect {
        let width = min(max(frame.width, minimumSize), imageSize.width)
        let height = min(max(frame.height, minimumSize), imageSize.height)
        let x = min(max(frame.minX, 0), max(0, imageSize.width - width))
        let y = min(max(frame.minY, 0), max(0, imageSize.height - height))
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
