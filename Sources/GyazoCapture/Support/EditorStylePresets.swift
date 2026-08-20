import CoreGraphics

enum EditorStylePresets {
    static let fontSizes: [CGFloat] = [12, 14, 16, 18, 20, 24, 28, 32, 40, 48, 64, 80, 96]
    static let magnificationScales: [CGFloat] = [1.5, 2, 2.5, 3]

    static func fontSizeChoices(including current: CGFloat) -> [CGFloat] {
        Array(Set(fontSizes + [current])).sorted()
    }
}
