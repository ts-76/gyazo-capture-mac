import AppKit
import Foundation

enum EditorTool: String, CaseIterable, Identifiable {
    case select
    case rectangle
    case crop
    case text
    case line
    case arrow
    case highlight
    case ellipse
    case redaction
    case blur
    case mosaic
    case magnifier

    var id: String { rawValue }

    var label: String {
        switch self {
        case .select: return "選択"
        case .rectangle: return "矩形"
        case .crop: return "クロップ"
        case .text: return "テキスト"
        case .line: return "直線"
        case .arrow: return "矢印"
        case .highlight: return "ハイライト"
        case .ellipse: return "楕円"
        case .redaction: return "墨消し"
        case .blur: return "ブラー"
        case .mosaic: return "モザイク"
        case .magnifier: return "ルーペ"
        }
    }

    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .rectangle: return "rectangle"
        case .crop: return "crop"
        case .text: return "textformat"
        case .line: return "minus"
        case .arrow: return "arrow.right"
        case .highlight: return "highlighter"
        case .ellipse: return "circle"
        case .redaction: return "paintbrush.fill"
        case .blur: return "drop.fill"
        case .mosaic: return "square.grid.3x3.fill"
        case .magnifier: return "magnifyingglass"
        }
    }

    var annotationKind: AnnotationKind? {
        switch self {
        case .select: return nil
        case .crop: return nil
        case .rectangle: return .rectangle
        case .text: return .text
        case .line: return .line
        case .arrow: return .arrow
        case .highlight: return .highlight
        case .ellipse: return .ellipse
        case .redaction: return .redaction
        case .blur: return .blur
        case .mosaic: return .mosaic
        case .magnifier: return .magnifier
        }
    }
}

enum AnnotationKind: String, Equatable {
    case rectangle
    case text
    case line
    case arrow
    case highlight
    case ellipse
    case redaction
    case blur
    case mosaic
    case magnifier

    var isMask: Bool {
        self == .blur || self == .mosaic
    }
}

struct AnnotationItem: Identifiable, Equatable {
    let id: UUID
    var kind: AnnotationKind
    var frame: CGRect
    var text: String
    var colorHex: String
    var lineWidth: CGFloat
    var fillOpacity: CGFloat
    var startUnitPoint: CGPoint
    var endUnitPoint: CGPoint
    var fontSize: CGFloat
    var effectStrength: CGFloat
    var magnification: CGFloat
    var magnifierDestinationOffset: CGSize

    init(
        id: UUID = UUID(),
        kind: AnnotationKind,
        frame: CGRect,
        text: String = "",
        colorHex: String = "#FF3B30",
        lineWidth: CGFloat = 4,
        fillOpacity: CGFloat = 0.35,
        startUnitPoint: CGPoint = .zero,
        endUnitPoint: CGPoint = CGPoint(x: 1, y: 0),
        fontSize: CGFloat = 24,
        effectStrength: CGFloat = 16,
        magnification: CGFloat = 2,
        magnifierDestinationOffset: CGSize = .zero
    ) {
        self.id = id
        self.kind = kind
        self.frame = frame
        self.text = text
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.fillOpacity = fillOpacity
        self.startUnitPoint = startUnitPoint
        self.endUnitPoint = endUnitPoint
        self.fontSize = fontSize
        self.effectStrength = effectStrength
        self.magnification = magnification
        self.magnifierDestinationOffset = magnifierDestinationOffset
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        self.init(
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}
