import AppKit
import SwiftUI

enum AnnotationCanvasCoordinateSpace {
    static let name = "annotation-canvas"
}

struct AnnotationCanvasView: View {
    @ObservedObject var model: EditorModel
    @State private var draftCropRect: CGRect?

    var body: some View {
        GeometryReader { proxy in
            let fitted = fittedSize(container: proxy.size, image: model.imagePixelSize)
            let scale = fitted.width / model.imagePixelSize.width

            ZStack {
                Image(nsImage: model.baseImage)
                    .resizable()
                    .frame(width: fitted.width, height: fitted.height)
                    .contentShape(Rectangle())
                    .gesture(drawingGesture(viewSize: fitted))

                if let preview = draftCropRect {
                    let viewFrame = CGRect(
                        x: preview.minX * scale,
                        y: preview.minY * scale,
                        width: preview.width * scale,
                        height: preview.height * scale
                    )
                    Rectangle()
                        .fill(Color(nsColor: .systemBlue).opacity(0.08))
                        .frame(width: viewFrame.width, height: viewFrame.height)
                        .overlay(
                            Rectangle()
                                .stroke(
                                    Color.white,
                                    style: StrokeStyle(lineWidth: 1, dash: [6, 4], dashPhase: 1)
                                )
                        )
                        .position(x: viewFrame.midX, y: viewFrame.midY)
                }

                ForEach(model.annotations.filter { $0.kind.isMask }) { annotation in
                    AnnotationLayerView(
                        model: model,
                        annotationID: annotation.id,
                        scale: scale
                    )
                }
                .allowsHitTesting(model.tool == .select)

                ForEach(model.annotations.filter { !$0.kind.isMask && $0.kind != .magnifier }) { annotation in
                    AnnotationLayerView(
                        model: model,
                        annotationID: annotation.id,
                        scale: scale
                    )
                }
                .allowsHitTesting(model.tool == .select)

                ForEach(model.annotations.filter { $0.kind == .magnifier }) { annotation in
                    MagnifierAnnotationLayerView(
                        model: model,
                        annotationID: annotation.id,
                        scale: scale
                    )
                }
                .allowsHitTesting(model.tool == .select)
            }
            .frame(width: fitted.width, height: fitted.height)
            .coordinateSpace(name: AnnotationCanvasCoordinateSpace.name)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .clipped()
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func fittedSize(container: CGSize, image: CGSize) -> CGSize {
        guard container.width > 0, container.height > 0, image.width > 0, image.height > 0 else {
            return .zero
        }
        let scale = min(container.width / image.width, container.height / image.height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }

    private func drawingGesture(viewSize: CGSize) -> some Gesture {
        DragGesture(
            minimumDistance: 0,
            coordinateSpace: .named(AnnotationCanvasCoordinateSpace.name)
        )
            .onChanged { value in
                guard model.tool == .crop else {
                    draftCropRect = nil
                    return
                }
                draftCropRect = translatedRect(
                    from: translatedPoint(from: value.startLocation, in: viewSize),
                    to: translatedPoint(from: value.location, in: viewSize)
                )
            }
            .onEnded { value in
                guard model.tool != .select else {
                    model.selectedID = nil
                    draftCropRect = nil
                    return
                }
                defer { draftCropRect = nil }
                let startPoint = translatedPoint(
                    from: value.startLocation,
                    in: viewSize
                )
                let endPoint = translatedPoint(
                    from: value.location,
                    in: viewSize
                )
                let rawFrame = translatedRect(from: startPoint, to: endPoint)
                guard model.tool != .crop else {
                    model.applyCrop(to: rawFrame)
                    return
                }
                guard let kind = model.tool.annotationKind else { return }
                let start = CGPoint(x: rawFrame.minX, y: rawFrame.minY)
                let frame: CGRect
                switch kind {
                case .text:
                    if rawFrame.width < 40 || rawFrame.height < 24 {
                        frame = CGRect(x: start.x, y: start.y, width: 220, height: 64)
                    } else {
                        frame = rawFrame
                    }
                case .line, .arrow:
                    frame = rawFrame
                case .highlight:
                    if rawFrame.width < 120 || rawFrame.height < 48 {
                        frame = CGRect(x: start.x, y: start.y, width: 220, height: 48)
                    } else {
                        frame = rawFrame
                    }
                case .magnifier:
                    if rawFrame.width < 40 || rawFrame.height < 40 {
                        frame = CGRect(
                            x: start.x,
                            y: start.y,
                            width: MagnifierGeometry.defaultSourceDiameter,
                            height: MagnifierGeometry.defaultSourceDiameter
                        )
                    } else {
                        let diameter = max(rawFrame.width, rawFrame.height)
                        frame = CGRect(
                            x: rawFrame.minX,
                            y: rawFrame.minY,
                            width: diameter,
                            height: diameter
                        )
                    }
                case .blur, .mosaic, .redaction, .rectangle, .ellipse:
                    if rawFrame.width < 40 || rawFrame.height < 40 {
                        if kind == .rectangle || kind == .redaction {
                            frame = CGRect(x: start.x, y: start.y, width: 160, height: 96)
                        } else if kind == .blur || kind == .mosaic {
                            frame = CGRect(x: start.x, y: start.y, width: 180, height: 120)
                        } else {
                            frame = CGRect(x: start.x, y: start.y, width: 160, height: 96)
                        }
                    } else {
                        frame = rawFrame
                    }
                }
                model.addAnnotation(
                    kind: kind,
                    frame: frame,
                    start: startPoint,
                    end: endPoint
                )
            }
    }

    private func translatedPoint(from point: CGPoint, in viewSize: CGSize) -> CGPoint {
        let scaleX = model.imagePixelSize.width / viewSize.width
        let scaleY = model.imagePixelSize.height / viewSize.height
        return CGPoint(x: point.x * scaleX, y: point.y * scaleY)
    }

    private func translatedRect(from startPoint: CGPoint, to endPoint: CGPoint) -> CGRect {
        return CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }
}

private struct AnnotationLayerView: View {
    @ObservedObject var model: EditorModel
    let annotationID: UUID
    let scale: CGFloat

    @State private var moveStartFrame: CGRect?
    @State private var resizeStartFrame: CGRect?

    private var item: AnnotationItem? {
        model.annotations.first { $0.id == annotationID }
    }

    var body: some View {
        if let item {
            let viewFrame = CGRect(
                x: item.frame.minX * scale,
                y: item.frame.minY * scale,
                width: item.frame.width * scale,
                height: item.frame.height * scale
            )
            ZStack(alignment: .bottomTrailing) {
                annotationContent(item)
                    .frame(width: viewFrame.width, height: viewFrame.height)
                    .contentShape(Rectangle())
                    .overlay(selectionBorder)
                    .gesture(moveGesture)
                    .onTapGesture { model.select(annotationID) }

                if model.selectedID == annotationID {
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(.blue, lineWidth: 2))
                        .frame(width: 12, height: 12)
                        .offset(x: 6, y: 6)
                        .gesture(resizeGesture)
                }
            }
            .frame(width: viewFrame.width, height: viewFrame.height)
            .position(x: viewFrame.midX, y: viewFrame.midY)
        }
    }

    @ViewBuilder
    private func annotationContent(_ item: AnnotationItem) -> some View {
        let color = Color(nsColor: NSColor(hex: item.colorHex) ?? .systemRed)
        let linePoints = AnnotationFrameTransformer.lineEndpoints(item)
        switch item.kind {
        case .rectangle:
            Rectangle()
                .stroke(color, lineWidth: max(1, item.lineWidth * scale))
        case .line:
            GeometryReader { _ in
                let start = CGPoint(
                    x: (linePoints.0.x - item.frame.minX) * scale,
                    y: (linePoints.0.y - item.frame.minY) * scale
                )
                let end = CGPoint(
                    x: (linePoints.1.x - item.frame.minX) * scale,
                    y: (linePoints.1.y - item.frame.minY) * scale
                )
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: max(1, item.lineWidth * scale), lineCap: .round, lineJoin: .round)
                )
            }
        case .arrow:
            GeometryReader { _ in
                let start = CGPoint(
                    x: (linePoints.0.x - item.frame.minX) * scale,
                    y: (linePoints.0.y - item.frame.minY) * scale
                )
                let end = CGPoint(
                    x: (linePoints.1.x - item.frame.minX) * scale,
                    y: (linePoints.1.y - item.frame.minY) * scale
                )
                let dx = end.x - start.x
                let dy = end.y - start.y
                let angle = atan2(dy, dx)
                let length = max(20 * scale, hypot(dx, dy))
                let headLength = min(length * 0.35, 28 * scale)
                let headAngle = CGFloat.pi / 6
                let left = CGPoint(
                    x: end.x - headLength * cos(angle - headAngle),
                    y: end.y - headLength * sin(angle - headAngle)
                )
                let right = CGPoint(
                    x: end.x - headLength * cos(angle + headAngle),
                    y: end.y - headLength * sin(angle + headAngle)
                )

                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                    path.move(to: end)
                    path.addLine(to: left)
                    path.move(to: end)
                    path.addLine(to: right)
                }
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: max(1, item.lineWidth * scale), lineCap: .round, lineJoin: .round)
                )
            }
        case .highlight:
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(item.fillOpacity))
        case .ellipse:
            Ellipse()
                .stroke(color, lineWidth: max(1, item.lineWidth * scale))
        case .text:
            Text(item.text)
                .font(.system(size: max(10, item.fontSize * scale), weight: .semibold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(4)
        case .redaction:
            Rectangle()
                .fill(color)
        case .magnifier:
            EmptyView()
        case .blur, .mosaic:
            MaskEffectPreviewView(
                baseImage: model.baseImage,
                imagePixelSize: model.imagePixelSize,
                annotation: item,
                scale: scale,
                imageRevision: model.imageRevision
            )
        }
    }

    private var selectionBorder: some View {
        Rectangle()
            .stroke(
                model.selectedID == annotationID ? Color.blue : Color.clear,
                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
    }

    private var moveGesture: some Gesture {
        DragGesture(
            minimumDistance: 1,
            coordinateSpace: .named(AnnotationCanvasCoordinateSpace.name)
        )
            .onChanged { value in
                guard let current = item else { return }
                if moveStartFrame == nil {
                    moveStartFrame = current.frame
                    model.checkpoint()
                    model.select(annotationID)
                }
                guard let start = moveStartFrame else { return }
                model.setFrame(
                    AnnotationGeometry.translatedFrame(
                        from: start,
                        translation: value.translation,
                        canvasScale: scale
                    ),
                    for: annotationID
                )
            }
            .onEnded { _ in moveStartFrame = nil }
    }

    private var resizeGesture: some Gesture {
        DragGesture(
            minimumDistance: 1,
            coordinateSpace: .named(AnnotationCanvasCoordinateSpace.name)
        )
            .onChanged { value in
                guard let current = item else { return }
                if resizeStartFrame == nil {
                    resizeStartFrame = current.frame
                    model.checkpoint()
                }
                guard let start = resizeStartFrame else { return }
                model.setFrame(
                    AnnotationGeometry.resizedFrame(
                        from: start,
                        translation: value.translation,
                        canvasScale: scale
                    ),
                    for: annotationID
                )
            }
            .onEnded { _ in resizeStartFrame = nil }
    }
}
