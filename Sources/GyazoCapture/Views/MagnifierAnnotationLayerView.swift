import AppKit
import SwiftUI

struct MagnifierAnnotationLayerView: View {
    @ObservedObject var model: EditorModel
    let annotationID: UUID
    let scale: CGFloat

    @State private var sourceMoveStartFrame: CGRect?
    @State private var destinationMoveStartOffset: CGSize?
    @State private var resizeStartFrame: CGRect?

    private var item: AnnotationItem? {
        model.annotations.first { $0.id == annotationID }
    }

    var body: some View {
        GeometryReader { _ in
            if let item {
                let sourceFrame = scaled(item.frame)
                let destinationFrame = scaled(MagnifierGeometry.destinationFrame(for: item))
                let color = Color(nsColor: NSColor(hex: item.colorHex) ?? .systemRed)

                ZStack(alignment: .topLeading) {
                    connector(
                        sourceFrame: sourceFrame,
                        destinationFrame: destinationFrame,
                        color: color,
                        lineWidth: item.lineWidth
                    )

                    sourceCircle(frame: sourceFrame, color: color, lineWidth: item.lineWidth)
                        .allowsHitTesting(false)

                    destinationLens(
                        item: item,
                        destinationFrame: destinationFrame,
                        color: color
                    )
                    .allowsHitTesting(false)

                    destinationDragTarget(frame: destinationFrame)
                    sourceDragTarget(frame: sourceFrame)

                    if model.selectedID == annotationID {
                        resizeHandle(sourceFrame: sourceFrame)
                    }
                }
            }
        }
    }

    private func sourceCircle(frame: CGRect, color: Color, lineWidth: CGFloat) -> some View {
        Circle()
            .fill(Color.black.opacity(0.001))
            .overlay {
                Circle()
                    .stroke(.white, lineWidth: max(1, (lineWidth + 3) * scale))
                Circle()
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: max(1, lineWidth * scale),
                            dash: [6 * scale, 4 * scale]
                        )
                    )
            }
            .overlay {
                if model.selectedID == annotationID {
                    Circle().stroke(.blue, lineWidth: 1)
                }
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }

    private func sourceDragTarget(frame: CGRect) -> some View {
        let hitPadding: CGFloat = 8
        let hitWidth = max(24, frame.width + hitPadding * 2)
        let hitHeight = max(24, frame.height + hitPadding * 2)
        let hitOrigin = CGPoint(
            x: frame.midX - hitWidth / 2,
            y: frame.midY - hitHeight / 2
        )
        return Circle()
            .fill(Color.black.opacity(0.002))
            .frame(width: hitWidth, height: hitHeight)
            .contentShape(Circle())
            .highPriorityGesture(sourceMoveGesture)
            .simultaneousGesture(
                TapGesture().onEnded { model.select(annotationID) }
            )
            .help("ドラッグして拡大元を移動")
            .padding(.leading, hitOrigin.x)
            .padding(.top, hitOrigin.y)
    }

    private func destinationDragTarget(frame: CGRect) -> some View {
        Circle()
            .fill(Color.black.opacity(0.002))
            .frame(width: frame.width, height: frame.height)
            .contentShape(Circle())
            .gesture(destinationMoveGesture)
            .simultaneousGesture(
                TapGesture().onEnded { model.select(annotationID) }
            )
            .help("ドラッグして拡大円を移動")
            .padding(.leading, frame.minX)
            .padding(.top, frame.minY)
    }

    private func destinationLens(
        item: AnnotationItem,
        destinationFrame: CGRect,
        color: Color
    ) -> some View {
        let zoom = item.magnification
        let fullWidth = model.imagePixelSize.width * scale * zoom
        let fullHeight = model.imagePixelSize.height * scale * zoom
        let imagePosition = CGPoint(
            x: destinationFrame.width / 2
                + (model.imagePixelSize.width / 2 - item.frame.midX) * scale * zoom,
            y: destinationFrame.height / 2
                + (model.imagePixelSize.height / 2 - item.frame.midY) * scale * zoom
        )

        return ZStack {
            Image(nsImage: model.baseImage)
                .resizable()
                .interpolation(.high)
                .frame(width: fullWidth, height: fullHeight)
                .position(imagePosition)
        }
        .frame(width: destinationFrame.width, height: destinationFrame.height)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(.white, lineWidth: max(2, (item.lineWidth + 5) * scale))
            Circle().stroke(color, lineWidth: max(1, item.lineWidth * scale))
            if model.selectedID == annotationID {
                Circle().stroke(.blue, lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: max(2, 5 * scale), y: max(1, 2 * scale))
        .position(x: destinationFrame.midX, y: destinationFrame.midY)
    }

    private func connector(
        sourceFrame: CGRect,
        destinationFrame: CGRect,
        color: Color,
        lineWidth: CGFloat
    ) -> some View {
        let endpoints = connectorEndpoints(
            sourceFrame: sourceFrame,
            destinationFrame: destinationFrame
        )
        return Path { path in
            path.move(to: endpoints.0)
            path.addLine(to: endpoints.1)
        }
        .stroke(.white, style: StrokeStyle(lineWidth: max(1, (lineWidth + 4) * scale), lineCap: .round))
        .overlay {
            Path { path in
                path.move(to: endpoints.0)
                path.addLine(to: endpoints.1)
            }
            .stroke(color, style: StrokeStyle(lineWidth: max(1, lineWidth * scale), lineCap: .round))
        }
        .allowsHitTesting(false)
    }

    private func resizeHandle(sourceFrame: CGRect) -> some View {
        Circle()
            .fill(.white)
            .overlay(Circle().stroke(.blue, lineWidth: 2))
            .frame(width: 12, height: 12)
            .position(x: sourceFrame.maxX, y: sourceFrame.maxY)
            .gesture(resizeGesture)
    }

    private var sourceMoveGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(AnnotationCanvasCoordinateSpace.name))
            .onChanged { value in
                guard let current = item else { return }
                if sourceMoveStartFrame == nil {
                    sourceMoveStartFrame = current.frame
                    model.checkpoint()
                    model.select(annotationID)
                }
                guard let start = sourceMoveStartFrame else { return }
                model.setFrame(
                    AnnotationGeometry.translatedFrame(
                        from: start,
                        translation: value.translation,
                        canvasScale: scale
                    ),
                    for: annotationID
                )
            }
            .onEnded { _ in sourceMoveStartFrame = nil }
    }

    private var destinationMoveGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(AnnotationCanvasCoordinateSpace.name))
            .onChanged { value in
                guard let current = item else { return }
                if destinationMoveStartOffset == nil {
                    destinationMoveStartOffset = current.magnifierDestinationOffset
                    model.checkpoint()
                    model.select(annotationID)
                }
                guard let start = destinationMoveStartOffset, scale > 0 else { return }
                model.setMagnifierDestinationOffset(
                    CGSize(
                        width: start.width + value.translation.width / scale,
                        height: start.height + value.translation.height / scale
                    ),
                    for: annotationID
                )
            }
            .onEnded { _ in destinationMoveStartOffset = nil }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(AnnotationCanvasCoordinateSpace.name))
            .onChanged { value in
                guard let current = item else { return }
                if resizeStartFrame == nil {
                    resizeStartFrame = current.frame
                    model.checkpoint()
                }
                guard let start = resizeStartFrame, scale > 0 else { return }
                let diameter = max(
                    start.width + value.translation.width / scale,
                    start.height + value.translation.height / scale
                )
                model.setFrame(
                    CGRect(x: start.minX, y: start.minY, width: diameter, height: diameter),
                    for: annotationID
                )
            }
            .onEnded { _ in resizeStartFrame = nil }
    }

    private func scaled(_ frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX * scale,
            y: frame.minY * scale,
            width: frame.width * scale,
            height: frame.height * scale
        )
    }

    private func connectorEndpoints(
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
}
