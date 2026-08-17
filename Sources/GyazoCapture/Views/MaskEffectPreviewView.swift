import AppKit
import SwiftUI

struct MaskEffectPreviewView: View {
    let baseImage: NSImage
    let imagePixelSize: CGSize
    let annotation: AnnotationItem
    let scale: CGFloat
    let imageRevision: Int

    @State private var filteredImage: NSImage?

    var body: some View {
        GeometryReader { _ in
            if let filteredImage {
                let fullWidth = imagePixelSize.width * scale
                let fullHeight = imagePixelSize.height * scale

                Image(nsImage: filteredImage)
                    .resizable()
                    .interpolation(annotation.kind == .mosaic ? .none : .high)
                    .frame(width: fullWidth, height: fullHeight)
                    .position(
                        x: fullWidth / 2 - annotation.frame.minX * scale,
                        y: fullHeight / 2 - annotation.frame.minY * scale
                    )
            } else {
                Rectangle()
                    .fill(.secondary.opacity(0.15))
            }
        }
        .clipped()
        .onAppear(perform: refresh)
        .onChange(of: annotation.kind) { _ in refresh() }
        .onChange(of: annotation.effectStrength) { _ in refresh() }
        .onChange(of: imageRevision) { _ in refresh() }
    }

    private func refresh() {
        filteredImage = try? MaskEffectRenderer.filteredImage(
            baseImage: baseImage,
            kind: annotation.kind,
            strength: annotation.effectStrength
        )
    }
}
