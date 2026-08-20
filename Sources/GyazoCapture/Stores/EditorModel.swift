import AppKit
import Combine
import Foundation

@MainActor
final class EditorModel: ObservableObject {
    @Published var annotations: [AnnotationItem] = []
    @Published var selectedID: UUID?
    @Published var imageRevision = 0
    @Published var tool: EditorTool = .select
    @Published var currentColorHex = "#FF3B30"
    @Published var currentLineWidth: CGFloat = 4
    @Published var currentFontSize: CGFloat = 24
    @Published var currentFillOpacity: CGFloat = 0.35
    @Published var currentMaskStrength: CGFloat = 16
    @Published var currentMagnification: CGFloat = 2
    @Published var fileName: String
    @Published var descriptionText = ""
    @Published var collectionID = ""
    @Published var accessPolicy: GyazoAccessPolicy
    @Published var isUploading = false
    @Published var statusMessage = ""
    @Published var uploadFailed = false

    let sourceURL: URL
    @Published var baseImage: NSImage
    @Published var imagePixelSize: CGSize

    private struct EditorSnapshot: Equatable {
        let baseImagePNGData: Data
        let imagePixelSize: CGSize
        let annotations: [AnnotationItem]
        let selectedID: UUID?
        let imageRevision: Int
    }

    private var undoStack: [EditorSnapshot] = []
    private var redoStack: [EditorSnapshot] = []

    init(sourceURL: URL, image: NSImage, settings: SettingsStore) throws {
        self.sourceURL = sourceURL
        self.baseImage = image
        self.imagePixelSize = try ImageCompositor.pixelSize(of: image)
        self.fileName = ImageExportService.defaultPNGFileName()
        self.collectionID = settings.defaultCollectionID
        self.accessPolicy = settings.defaultAccessPolicy
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var selectedAnnotation: AnnotationItem? {
        annotations.first { $0.id == selectedID }
    }

    func checkpoint() {
        guard let snapshot = snapshot() else { return }
        guard undoStack.last != snapshot else { return }
        undoStack.append(snapshot)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        guard let current = snapshot() else { return }
        redoStack.append(current)
        restore(previous)
        objectWillChange.send()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        guard let current = snapshot() else { return }
        undoStack.append(current)
        restore(next)
        objectWillChange.send()
    }

    func addAnnotation(kind: AnnotationKind, frame: CGRect, start: CGPoint? = nil, end: CGPoint? = nil) {
        checkpoint()
        let normalized = kind == .magnifier
            ? MagnifierGeometry.circularSourceFrame(frame, within: imagePixelSize)
            : clamped(frame: frame)
        let sourceStart = start ?? CGPoint(
            x: normalized.midX,
            y: normalized.midY
        )
        let sourceEnd = end ?? CGPoint(
            x: normalized.maxX,
            y: normalized.midY
        )
        let startUnitPoint = (kind == .line || kind == .arrow) ?
            AnnotationFrameTransformer.unitPoint(for: sourceStart, in: normalized) :
            .zero
        let endUnitPoint = (kind == .line || kind == .arrow) ?
            AnnotationFrameTransformer.unitPoint(for: sourceEnd, in: normalized) :
            CGPoint(x: 1, y: 0)

        let colorHex = kind == .redaction ? "#000000" : currentColorHex
        let fillOpacity = kind == .redaction ? 1 : (kind == .highlight ? currentFillOpacity : 1)
        let destinationOffset = kind == .magnifier
            ? MagnifierGeometry.defaultDestinationOffset(
                sourceFrame: normalized,
                magnification: currentMagnification,
                imageSize: imagePixelSize
            )
            : .zero
        let item = AnnotationItem(
            kind: kind,
            frame: normalized,
            text: kind == .text ? "テキスト" : "",
            colorHex: colorHex,
            lineWidth: currentLineWidth,
            fillOpacity: fillOpacity,
            startUnitPoint: startUnitPoint,
            endUnitPoint: endUnitPoint,
            fontSize: currentFontSize,
            effectStrength: currentMaskStrength,
            magnification: currentMagnification,
            magnifierDestinationOffset: destinationOffset
        )
        annotations.append(item)
        selectedID = item.id
        tool = .select
        objectWillChange.send()
    }

    func setFrame(_ frame: CGRect, for id: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        if annotations[index].kind == .magnifier {
            let destinationFrame = MagnifierGeometry.destinationFrame(
                for: annotations[index]
            )
            let destinationCenter = CGPoint(
                x: destinationFrame.midX,
                y: destinationFrame.midY
            )
            let sourceFrame = MagnifierGeometry.circularSourceFrame(frame, within: imagePixelSize)
            annotations[index].frame = sourceFrame
            annotations[index].magnifierDestinationOffset = MagnifierGeometry.clampedDestinationOffset(
                CGSize(
                    width: destinationCenter.x - sourceFrame.midX,
                    height: destinationCenter.y - sourceFrame.midY
                ),
                sourceFrame: sourceFrame,
                magnification: annotations[index].magnification,
                imageSize: imagePixelSize
            )
        } else {
            annotations[index].frame = clamped(frame: frame)
        }
    }

    func setMagnifierDestinationOffset(_ offset: CGSize, for id: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == id }),
              annotations[index].kind == .magnifier else { return }
        annotations[index].magnifierDestinationOffset = MagnifierGeometry.clampedDestinationOffset(
            offset,
            sourceFrame: annotations[index].frame,
            magnification: annotations[index].magnification,
            imageSize: imagePixelSize
        )
    }

    func setText(_ text: String, for id: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        guard annotations[index].text != text else { return }
        checkpoint()
        annotations[index].text = text
    }

    func select(_ id: UUID) {
        selectedID = id
        if let annotation = annotations.first(where: { $0.id == id }) {
            currentColorHex = annotation.colorHex
            currentLineWidth = annotation.lineWidth
            currentFillOpacity = annotation.fillOpacity
            currentFontSize = annotation.fontSize
            currentMaskStrength = annotation.effectStrength
            currentMagnification = annotation.magnification
        }
    }

    func applyColor(_ hex: String) {
        guard let selectedID,
              let index = annotations.firstIndex(where: { $0.id == selectedID }) else {
            currentColorHex = hex
            return
        }
        guard annotations[index].kind != .redaction else {
            currentColorHex = "#000000"
            return
        }
        currentColorHex = hex
        checkpoint()
        annotations[index].colorHex = hex
    }

    func applyLineWidth(_ width: CGFloat) {
        currentLineWidth = width
        guard let selectedID,
              let index = annotations.firstIndex(where: { $0.id == selectedID }) else { return }
        checkpoint()
        annotations[index].lineWidth = width
    }

    func applyFillOpacity(_ opacity: CGFloat) {
        currentFillOpacity = max(0, min(1, opacity))
        guard let selectedID,
              let index = annotations.firstIndex(where: { $0.id == selectedID }),
              annotations[index].kind == .highlight else { return }
        checkpoint()
        annotations[index].fillOpacity = max(0, min(1, opacity))
    }

    func applyFontSize(_ size: CGFloat) {
        currentFontSize = size
        guard let selectedID,
              let index = annotations.firstIndex(where: { $0.id == selectedID }),
              annotations[index].kind == .text else { return }
        checkpoint()
        annotations[index].fontSize = size
    }

    func applyMaskStrength(_ strength: CGFloat) {
        currentMaskStrength = strength
        guard let selectedID,
              let index = annotations.firstIndex(where: { $0.id == selectedID }),
              annotations[index].kind.isMask else { return }
        checkpoint()
        annotations[index].effectStrength = strength
    }

    func applyMagnification(_ magnification: CGFloat) {
        currentMagnification = magnification
        guard let selectedID,
              let index = annotations.firstIndex(where: { $0.id == selectedID }),
              annotations[index].kind == .magnifier else { return }
        checkpoint()
        annotations[index].magnification = magnification
        annotations[index].magnifierDestinationOffset = MagnifierGeometry.clampedDestinationOffset(
            annotations[index].magnifierDestinationOffset,
            sourceFrame: annotations[index].frame,
            magnification: magnification,
            imageSize: imagePixelSize
        )
    }

    func deleteSelected() {
        guard let selectedID,
              let index = annotations.firstIndex(where: { $0.id == selectedID }) else { return }
        checkpoint()
        annotations.remove(at: index)
        self.selectedID = nil
        objectWillChange.send()
    }

    func applyCrop(to frame: CGRect) {
        let clamped = AnnotationFrameTransformer.clampedFrame(frame, within: imagePixelSize)
        guard clamped.width >= 2, clamped.height >= 2 else { return }
        guard clamped.width < imagePixelSize.width || clamped.height < imagePixelSize.height else { return }
        guard let cropped = try? ImageTransformService.croppedImage(baseImage, to: clamped) else {
            return
        }

        checkpoint()
        replaceBaseImage(cropped)
        annotations = annotations.compactMap { annotation in
            let updated = (annotation.kind.isMask || annotation.kind == .magnifier)
                ? AnnotationFrameTransformer.clippedFrameAfterCrop(annotation.frame, cropRect: clamped)
                : AnnotationFrameTransformer.frameAfterCrop(annotation.frame, cropRect: clamped)
            guard let updated else {
                return nil
            }
            var next = annotation
            next.frame = updated
            if annotation.kind == .magnifier {
                let destinationCenter = CGPoint(
                    x: annotation.frame.midX + annotation.magnifierDestinationOffset.width - clamped.minX,
                    y: annotation.frame.midY + annotation.magnifierDestinationOffset.height - clamped.minY
                )
                let translatedOffset = CGSize(
                    width: destinationCenter.x - updated.midX,
                    height: destinationCenter.y - updated.midY
                )
                next.magnifierDestinationOffset = MagnifierGeometry.clampedDestinationOffset(
                    translatedOffset,
                    sourceFrame: updated,
                    magnification: next.magnification,
                    imageSize: imagePixelSize
                )
            }
            return next
        }
        selectedID = nil
    }

    func rotateClockwise() {
        applyRotation(clockwise: true)
    }

    func rotateCounterClockwise() {
        applyRotation(clockwise: false)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: sourceURL)
    }

    private func clamped(frame: CGRect) -> CGRect {
        AnnotationGeometry.clampedFrame(frame, within: imagePixelSize)
    }

    private func applyRotation(clockwise: Bool) {
        guard let rotated = try? ImageTransformService.rotatedImage(baseImage, clockwise: clockwise) else {
            return
        }

        checkpoint()
        let sourceImageSize = imagePixelSize
        let nextImageSize = AnnotationFrameTransformer.rotatedImageSize(afterRotating: sourceImageSize)
        annotations = annotations.map { annotation in
            var next = annotation
            next.frame = AnnotationFrameTransformer.clampedRotatedFrame(
                annotation.frame,
                sourceImageSize: sourceImageSize,
                destinationImageSize: nextImageSize,
                clockwise: clockwise
            )
            if annotation.kind == .line || annotation.kind == .arrow {
                next.startUnitPoint = AnnotationFrameTransformer.rotateUnitPoint(
                    annotation.startUnitPoint,
                    clockwise: clockwise
                )
                next.endUnitPoint = AnnotationFrameTransformer.rotateUnitPoint(
                    annotation.endUnitPoint,
                    clockwise: clockwise
                )
            } else if annotation.kind == .magnifier {
                next.magnifierDestinationOffset = MagnifierGeometry.rotatedOffset(
                    annotation.magnifierDestinationOffset,
                    clockwise: clockwise
                )
            }
            return next
        }
        replaceBaseImage(rotated, with: nextImageSize)
    }

    private func snapshot() -> EditorSnapshot? {
        guard let baseImageData = baseImage.pngData() else { return nil }
        return EditorSnapshot(
            baseImagePNGData: baseImageData,
            imagePixelSize: imagePixelSize,
            annotations: annotations,
            selectedID: selectedID,
            imageRevision: imageRevision
        )
    }

    private func restore(_ snapshot: EditorSnapshot) {
        guard let restored = NSImage(data: snapshot.baseImagePNGData) else {
            return
        }
        baseImage = restored
        imagePixelSize = snapshot.imagePixelSize
        imageRevision = snapshot.imageRevision
        annotations = snapshot.annotations
        selectedID = snapshot.selectedID
    }

    private func replaceBaseImage(_ image: NSImage, with imageSize: CGSize? = nil) {
        baseImage = image
        if let size = imageSize ?? (try? ImageCompositor.pixelSize(of: image)) {
            imagePixelSize = size
        }
        imageRevision += 1
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let representation = NSBitmapImageRep(data: tiffData) else { return nil }
        return representation.representation(using: .png, properties: [:])
    }
}
