import AppKit
import Foundation
import Dispatch

enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): return message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw CheckFailure.failed(message) }
}

func expectNearlyEqual(_ lhs: CGPoint, _ rhs: CGPoint, message: String, tolerance: CGFloat = 1e-6) throws {
    try expect(abs(lhs.x - rhs.x) <= tolerance && abs(lhs.y - rhs.y) <= tolerance, message)
}

func testImage(width: CGFloat, height: CGFloat, color: NSColor = .white) -> NSImage {
    let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(width),
        pixelsHigh: Int(height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    color.setFill()
    let rect = NSRect(origin: .zero, size: NSSize(width: width, height: height))
    rect.fill()
    NSGraphicsContext.restoreGraphicsState()
    let image = NSImage(size: NSSize(width: width, height: height))
    image.addRepresentation(representation)
    return image
}

func horizontalBandsImage(width: Int, height: Int) -> NSImage {
    let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: width * 4,
        bitsPerPixel: 32
    )!
    let red = NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1)
    let blue = NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
    for y in 0..<height {
        for x in 0..<width {
            representation.setColor(y < height / 2 ? red : blue, atX: x, y: y)
        }
    }
    let image = NSImage(size: NSSize(width: width, height: height))
    image.addRepresentation(representation)
    return image
}

func retinaHorizontalBandsImage(width: Int, height: Int, scale: CGFloat = 2) -> NSImage {
    let image = horizontalBandsImage(width: width, height: height)
    let retinaImage = NSImage(
        size: NSSize(
            width: CGFloat(width) / scale,
            height: CGFloat(height) / scale
        )
    )
    for representation in image.representations {
        retinaImage.addRepresentation(representation)
    }
    return retinaImage
}

func expectColor(
    _ actual: NSColor?,
    matches expected: NSColor,
    message: String,
    tolerance: CGFloat = 0.25
) throws {
    guard let actual = actual?.usingColorSpace(.deviceRGB),
          let expected = expected.usingColorSpace(.deviceRGB) else {
        throw CheckFailure.failed("\(message): RGBへ変換できません")
    }
    try expect(
        abs(actual.redComponent - expected.redComponent) <= tolerance
            && abs(actual.greenComponent - expected.greenComponent) <= tolerance
            && abs(actual.blueComponent - expected.blueComponent) <= tolerance,
        "\(message) (actual: \(actual.redComponent), \(actual.greenComponent), \(actual.blueComponent))"
    )
}

@MainActor
func makeEditorModel(image: NSImage, fileName: String) throws -> EditorModel {
    let settings = SettingsStore(loadKeychain: false)
    return try EditorModel(
        sourceURL: URL(fileURLWithPath: "/tmp/gyazo_capture_check_\(fileName).png"),
        image: image,
        settings: settings
    )
}

@MainActor
func runChecks() throws {
    try expect(
        CollectionPreset.extractCollectionID(from: "https://gyazo.com/collections/700efdb22a0a5648d9834fd285ce3620")
            == "700efdb22a0a5648d9834fd285ce3620",
        "GyazoコレクションURLからIDを抽出できません"
    )
    try expect(
        CollectionPreset.extractCollectionID(from: "not an id") == nil,
        "不正なコレクションIDを拒否できません"
    )
    try expect(
        CollectionPreset.extractCollectionID(from: "https://team.gyazo.com/collections/700efdb22a0a5648d9834fd285ce3620")
            == "700efdb22a0a5648d9834fd285ce3620",
        "Gyazo TeamsのコレクションURLからIDを抽出できません"
    )
    try expect(
        CollectionPreset.extractCollectionID(from: "https://gyazo.com/700efdb22a0a5648d9834fd285ce3620") == nil,
        "画像URLをコレクションURLとして受け入れています"
    )

    let dragRect = CGRect(x: 280, y: 220, width: -130, height: -60)
    let normalizedRect = AppConstants.normalizeSelectionRect(dragRect)
    let topLeftRect = AppConstants.screencaptureTopLeftRect(for: normalizedRect, primaryScreenMaxY: 900)
    try expect(normalizedRect == CGRect(x: 150, y: 160, width: 130, height: 60), "矩形の正規化が不正です")
    try expect(topLeftRect == CGRect(x: 150, y: 680, width: 130, height: 60), "screencapture座標変換が不正です")
    let sideRect = CGRect(x: -320, y: 90, width: 80, height: 40)
    let sideTopLeft = AppConstants.screencaptureTopLeftRect(for: sideRect, primaryScreenMaxY: 900)
    try expect(sideTopLeft == CGRect(x: -320, y: 770, width: 80, height: 40), "副画面の負のoriginで座標変換が不正です")
    let screenshotArguments = AppConstants.screencaptureRectangleArguments(
        from: normalizedRect,
        primaryScreenMaxY: 900
    )
    try expect(
        screenshotArguments == ["-R", "150,680,130,60", "-x", "-t", "png"],
        "screencaptureの-R引数生成が不正です"
    )
    try expect(AppConstants.isSelectionRectUsable(CGRect(x: 10, y: 10, width: 0, height: 10)) == false, "ゼロ幅を許可しています")
    try expect(AppConstants.isSelectionRectUsable(CGRect(x: 10, y: 10, width: 10, height: 0)) == false, "ゼロ高さを許可しています")
    try expect(AppConstants.isSelectionRectUsable(CGRect(x: 10, y: 10, width: 0.5, height: 0.5)) == false, "幅/高さ1未満を許可しています")
    try expect(AppConstants.isValidCaptureHotKey(AppConstants.CaptureHotKey(keyCode: 18, modifiers: [.command, .shift])) == false, "スクリーンショット予約キーを許可しています")
    try expect(AppConstants.isValidCaptureHotKey(AppConstants.CaptureHotKey(keyCode: 21, modifiers: [.command, .shift, .control])) == false, "Control付きのmacOS標準スクリーンショットキーを許可しています")
    try expect(AppConstants.isValidCaptureHotKey(AppConstants.CaptureHotKey(keyCode: 23, modifiers: [])) == false, "修飾キーなしショートカットを許可しています")
    try expect(AppConstants.isValidCaptureHotKey(AppConstants.CaptureHotKey(keyCode: 35, modifiers: [.option])) == true, "有効なショートカットを拒否しています")
    try expect(Set(AppConstants.defaultCaptureHotKeys.values).count == AppConstants.CaptureMode.allCases.count, "キャプチャ方式の既定ショートカットが重複しています")
    try expect(AppConstants.defaultCaptureHotKeys.values.allSatisfy(AppConstants.isValidCaptureHotKey), "無効な既定ショートカットがあります")
    try expect(Set(AppConstants.CaptureMode.allCases.map(\.hotKeyRegistrationID)).count == AppConstants.CaptureMode.allCases.count, "ホットキー登録IDが重複しています")

    let hotKeySuiteName = "GyazoCaptureChecks.\(UUID().uuidString)"
    let hotKeyDefaults = UserDefaults(suiteName: hotKeySuiteName)!
    let hotKeySettings = SettingsStore(defaults: hotKeyDefaults, loadKeychain: false)
    let customWindowHotKey = AppConstants.CaptureHotKey(keyCode: 35, modifiers: [.option, .command])
    try hotKeySettings.applyCaptureHotKey(customWindowHotKey, for: .window)
    let reloadedHotKeySettings = SettingsStore(defaults: hotKeyDefaults, loadKeychain: false)
    try expect(reloadedHotKeySettings.captureHotKey(for: .window) == customWindowHotKey, "方式別ショートカットを永続化できません")
    do {
        try reloadedHotKeySettings.applyCaptureHotKey(customWindowHotKey, for: .selection)
        throw CheckFailure.failed("方式間で同じショートカットを許可しています")
    } catch CaptureHotKeyError.duplicateAssignment {
        // Expected.
    }
    hotKeyDefaults.removePersistentDomain(forName: hotKeySuiteName)

    try expect(EditorStylePresets.fontSizes.contains(24), "既定の文字サイズがプリセットにありません")
    try expect(
        EditorStylePresets.fontSizeChoices(including: 22).contains(22),
        "プリセット外の既存文字サイズを選択肢に保持できません"
    )
    try expect(EditorTool.blur.annotationKind == .blur, "ブラーツールを注釈種別へ変換できません")
    try expect(EditorTool.mosaic.annotationKind == .mosaic, "モザイクツールを注釈種別へ変換できません")
    try expect(EditorTool.line.annotationKind == .line, "直線ツールを注釈種別へ変換できません")
    try expect(EditorTool.arrow.annotationKind == .arrow, "矢印ツールを注釈種別へ変換できません")
    try expect(EditorTool.highlight.annotationKind == .highlight, "ハイライトツールを注釈種別へ変換できません")
    try expect(EditorTool.ellipse.annotationKind == .ellipse, "楕円ツールを注釈種別へ変換できません")
    try expect(EditorTool.redaction.annotationKind == .redaction, "墨消しツールを注釈種別へ変換できません")
    try expect(EditorTool.magnifier.annotationKind == .magnifier, "ルーペツールを注釈種別へ変換できません")
    try expect(AnnotationKind.blur.isMask && AnnotationKind.mosaic.isMask, "マスク種別の判定が不正です")
    try expect(!AnnotationKind.magnifier.isMask, "ルーペをマスク種別として扱っています")

    let encoded = FormURLEncoder.encode(["state": "a b", "code": "x+y"])
    try expect(String(data: encoded ?? Data(), encoding: .utf8) == "code=x+y&state=a%20b", "フォームエンコードが不正です")

    let pngHeader = Data([0x89, 0x50, 0x4E, 0x47])
    let multipart = MultipartFormData.build(
        boundary: "Boundary",
        fields: ["desc": "#sample"],
        fileField: "imagedata",
        filename: "capture.png",
        mimeType: "image/png",
        fileData: pngHeader
    )
    let multipartText = String(data: multipart, encoding: .isoLatin1) ?? ""
    try expect(multipartText.contains("name=\"desc\""), "multipartに説明フィールドがありません")
    try expect(multipartText.contains("filename=\"capture.png\""), "multipartにファイル名がありません")
    try expect(multipart.range(of: pngHeader) != nil, "multipartにPNGデータがありません")
    try expect(
        ImageExportService.normalizedPNGFileName("  作業メモ  ") == "作業メモ.png",
        "保存名へPNG拡張子を補完できません"
    )
    try expect(
        ImageExportService.normalizedPNGFileName("folder/capture.PNG") == "folder-capture.png",
        "保存名の危険な文字を除去できません"
    )

    let sourceFrame = CGRect(x: 40, y: 30, width: 120, height: 60)
    let translatedFrame = AnnotationGeometry.translatedFrame(
        from: sourceFrame,
        translation: CGSize(width: 30, height: -15),
        canvasScale: 0.5
    )
    try expect(translatedFrame == CGRect(x: 100, y: 0, width: 120, height: 60), "注釈の移動座標が不正です")

    let resizedFrame = AnnotationGeometry.resizedFrame(
        from: sourceFrame,
        translation: CGSize(width: 20, height: 10),
        canvasScale: 0.5
    )
    try expect(resizedFrame == CGRect(x: 40, y: 30, width: 160, height: 80), "注釈のリサイズ座標が不正です")

    let clampedFrame = AnnotationGeometry.clampedFrame(
        CGRect(x: 250, y: -20, width: 80, height: 10),
        within: CGSize(width: 300, height: 200)
    )
    try expect(clampedFrame == CGRect(x: 220, y: 0, width: 80, height: 20), "注釈の境界制約が不正です")

    let image = testImage(width: 120, height: 80, color: .white)
    let output = try ImageCompositor.pngData(
        baseImage: image,
        annotations: [AnnotationItem(kind: .rectangle, frame: CGRect(x: 10, y: 10, width: 50, height: 30))]
    )
    guard let representation = NSBitmapImageRep(data: output) else {
        throw CheckFailure.failed("合成後のPNGを読み取れません")
    }
    try expect(representation.pixelsWide == 120, "合成後の画像幅が変化しました")
    try expect(representation.pixelsHigh == 80, "合成後の画像高さが変化しました")

    let bands = horizontalBandsImage(width: 12, height: 10)
    let bandsOutput = try ImageCompositor.pngData(baseImage: bands, annotations: [])
    guard let bandsRepresentation = NSBitmapImageRep(data: bandsOutput) else {
        throw CheckFailure.failed("上下判定用のPNGを読み取れません")
    }
    try expectColor(
        bandsRepresentation.colorAt(x: 6, y: 1),
        matches: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1),
        message: "PNG出力の上側が反転しています"
    )
    try expectColor(
        bandsRepresentation.colorAt(x: 6, y: 8),
        matches: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1),
        message: "PNG出力の下側が反転しています"
    )

    let topCrop = try ImageTransformService.croppedImage(
        bands,
        to: CGRect(x: 0, y: 0, width: 12, height: 5)
    )
    guard let topCropData = topCrop.tiffRepresentation,
          let topCropRepresentation = NSBitmapImageRep(data: topCropData) else {
        throw CheckFailure.failed("クロップ後の画像を読み取れません")
    }
    try expectColor(
        topCropRepresentation.colorAt(x: 6, y: 1),
        matches: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1),
        message: "クロップが上下反対の領域を切り出しています"
    )

    let magnifier = AnnotationItem(
        kind: .magnifier,
        frame: CGRect(x: 5, y: 5, width: 20, height: 20),
        colorHex: "#007AFF",
        lineWidth: 3,
        magnification: 2,
        magnifierDestinationOffset: CGSize(width: 75, height: 45)
    )
    try expect(
        MagnifierGeometry.destinationFrame(for: magnifier) == CGRect(x: 70, y: 40, width: 40, height: 40),
        "ルーペの拡大円座標が不正です"
    )
    let magnifierBands = horizontalBandsImage(width: 120, height: 80)
    let magnifierOutput = try ImageCompositor.pngData(baseImage: magnifierBands, annotations: [magnifier])
    guard let magnifierRepresentation = NSBitmapImageRep(data: magnifierOutput) else {
        throw CheckFailure.failed("ルーペ描画後のPNGを読み取れません")
    }
    try expectColor(
        magnifierRepresentation.colorAt(x: 90, y: 60),
        matches: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1),
        message: "拡大円へ元領域を描画できません"
    )
    let retinaMagnifierOutput = try ImageCompositor.pngData(
        baseImage: retinaHorizontalBandsImage(width: 120, height: 80),
        annotations: [magnifier]
    )
    guard let retinaMagnifierRepresentation = NSBitmapImageRep(data: retinaMagnifierOutput) else {
        throw CheckFailure.failed("Retina画像のルーペ描画後PNGを読み取れません")
    }
    try expectColor(
        retinaMagnifierRepresentation.colorAt(x: 90, y: 60),
        matches: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1),
        message: "Retina画像の拡大円へ元領域を描画できません"
    )

    let maskedOutput = try ImageCompositor.pngData(
        baseImage: image,
        annotations: [
            AnnotationItem(
                kind: .blur,
                frame: CGRect(x: 5, y: 5, width: 50, height: 30),
                effectStrength: 12
            ),
            AnnotationItem(
                kind: .mosaic,
                frame: CGRect(x: 60, y: 35, width: 50, height: 30),
                effectStrength: 16
            )
        ]
    )
    guard let maskedRepresentation = NSBitmapImageRep(data: maskedOutput) else {
        throw CheckFailure.failed("マスク処理後のPNGを読み取れません")
    }
    try expect(maskedRepresentation.pixelsWide == 120, "マスク処理後の画像幅が変化しました")
    try expect(maskedRepresentation.pixelsHigh == 80, "マスク処理後の画像高さが変化しました")

    let vectorOutput = try ImageCompositor.pngData(
        baseImage: image,
        annotations: [
            AnnotationItem(kind: .line, frame: CGRect(x: 5, y: 40, width: 60, height: 12), lineWidth: 3),
            AnnotationItem(kind: .arrow, frame: CGRect(x: 15, y: 10, width: 70, height: 12), lineWidth: 3),
            AnnotationItem(kind: .ellipse, frame: CGRect(x: 40, y: 20, width: 30, height: 20), lineWidth: 2),
            AnnotationItem(kind: .highlight, frame: CGRect(x: 10, y: 50, width: 60, height: 20), colorHex: "#FFFF00", fillOpacity: 0.4),
            AnnotationItem(kind: .redaction, frame: CGRect(x: 80, y: 15, width: 24, height: 18), colorHex: "#000000")
        ]
    )
    guard let vectorRepresentation = NSBitmapImageRep(data: vectorOutput) else {
        throw CheckFailure.failed("形状描画後のPNGを読み取れません")
    }
    try expect(vectorRepresentation.pixelsWide == 120, "形状描画後の画像幅が変化しました")
    try expect(vectorRepresentation.pixelsHigh == 80, "形状描画後の画像高さが変化しました")

    let lineStart = CGPoint(x: 8, y: 46)
    let lineEnd = CGPoint(x: 48, y: 39)
    let lineSourceFrame = CGRect(x: 5, y: 30, width: 60, height: 20)
    let lineStartUnit = AnnotationFrameTransformer.unitPoint(for: lineStart, in: lineSourceFrame)
    let lineEndUnit = AnnotationFrameTransformer.unitPoint(for: lineEnd, in: lineSourceFrame)
    let lineForRender = AnnotationItem(
        kind: .line,
        frame: lineSourceFrame,
        startUnitPoint: lineStartUnit,
        endUnitPoint: lineEndUnit
    )
    let compositedLineEndpoints = AnnotationFrameTransformer.lineEndpoints(lineForRender)
    try expectNearlyEqual(compositedLineEndpoints.0, lineStart, message: "線/矢印の端点再変換が崩れています")
    try expectNearlyEqual(compositedLineEndpoints.1, lineEnd, message: "線/矢印の端点再変換が崩れています")

    let clockwisePoint = AnnotationFrameTransformer.rotateUnitPoint(CGPoint(x: 0.2, y: 0.75), clockwise: true)
    let counterClockwisePoint = AnnotationFrameTransformer.rotateUnitPoint(CGPoint(x: 0.2, y: 0.75), clockwise: false)
    try expectNearlyEqual(clockwisePoint, CGPoint(x: 0.25, y: 0.2), message: "CW回転ヘルパーの計算が不正です")
    try expectNearlyEqual(counterClockwisePoint, CGPoint(x: 0.75, y: 0.8), message: "CCW回転ヘルパーの計算が不正です")

    let modelAnnotationCheck = try makeEditorModel(image: testImage(width: 160, height: 120), fileName: "annotation-endpoints")
    modelAnnotationCheck.currentColorHex = "#00FF00"
    modelAnnotationCheck.addAnnotation(
        kind: .line,
        frame: CGRect(x: 30, y: 20, width: 90, height: 60),
        start: CGPoint(x: 30, y: 50),
        end: CGPoint(x: 90, y: 80)
    )
    guard let storedLine = modelAnnotationCheck.annotations.last else {
        throw CheckFailure.failed("新規作成した線注釈を取得できません")
    }
    try expect(storedLine.kind == .line, "線注釈の種類が正しくありません")
    try expectNearlyEqual(
        AnnotationFrameTransformer.point(from: storedLine.startUnitPoint, in: storedLine.frame),
        CGPoint(x: 30, y: 50),
        message: "線注釈の端点方向が保存されていません"
    )
    try expectNearlyEqual(
        AnnotationFrameTransformer.point(from: storedLine.endUnitPoint, in: storedLine.frame),
        CGPoint(x: 90, y: 80),
        message: "線注釈の端点方向が保存されていません"
    )

    modelAnnotationCheck.addAnnotation(
        kind: .arrow,
        frame: CGRect(x: 40, y: 40, width: 70, height: 30),
        start: CGPoint(x: 40, y: 55),
        end: CGPoint(x: 80, y: 60)
    )
    guard let storedArrow = modelAnnotationCheck.annotations.last(where: { $0.kind == .arrow }) else {
        throw CheckFailure.failed("新規作成した矢印注釈を取得できません")
    }
    try expectNearlyEqual(
        AnnotationFrameTransformer.point(from: storedArrow.startUnitPoint, in: storedArrow.frame),
        CGPoint(x: 40, y: 55),
        message: "矢印注釈の端点方向が保存されていません"
    )
    try expectNearlyEqual(
        AnnotationFrameTransformer.point(from: storedArrow.endUnitPoint, in: storedArrow.frame),
        CGPoint(x: 80, y: 60),
        message: "矢印注釈の端点方向が保存されていません"
    )

    guard let movableLineID = modelAnnotationCheck.annotations.first(where: { $0.kind == .line })?.id else {
        throw CheckFailure.failed("移動判定用の線注釈を取得できません")
    }
    let movableLineFrame = AnnotationGeometry.translatedFrame(
        from: modelAnnotationCheck.annotations.first(where: { $0.id == movableLineID })?.frame ?? .zero,
        translation: CGSize(width: 20, height: 10),
        canvasScale: 1
    )
    modelAnnotationCheck.setFrame(movableLineFrame, for: movableLineID)
    guard let movedLine = modelAnnotationCheck.annotations.first(where: { $0.id == movableLineID }) else {
        throw CheckFailure.failed("移動後の線注釈を取得できません")
    }
    try expectNearlyEqual(
        AnnotationFrameTransformer.point(from: movedLine.startUnitPoint, in: movedLine.frame),
        CGPoint(x: 50, y: 60),
        message: "線注釈の移動後の開始点がずれています"
    )
    try expectNearlyEqual(
        AnnotationFrameTransformer.point(from: movedLine.endUnitPoint, in: movedLine.frame),
        CGPoint(x: 110, y: 90),
        message: "線注釈の移動後の終了点がずれています"
    )

    let rotationEndpointModel = try makeEditorModel(image: testImage(width: 200, height: 120), fileName: "rotation-endpoint")
    rotationEndpointModel.addAnnotation(
        kind: .arrow,
        frame: CGRect(x: 40, y: 30, width: 100, height: 40),
        start: CGPoint(x: 50, y: 45),
        end: CGPoint(x: 90, y: 55)
    )
    guard let arrowID = rotationEndpointModel.annotations.first(where: { $0.kind == .arrow })?.id,
          let arrowBefore = rotationEndpointModel.annotations.first(where: { $0.id == arrowID }) else {
        throw CheckFailure.failed("回転用の矢印注釈を取得できません")
    }
    let startUnitBefore = arrowBefore.startUnitPoint
    let endUnitBefore = arrowBefore.endUnitPoint
    rotationEndpointModel.rotateClockwise()
    guard let arrowAfter = rotationEndpointModel.annotations.first(where: { $0.id == arrowID }) else {
        throw CheckFailure.failed("回転後の矢印注釈を取得できません")
    }
    let rotatedStart = AnnotationFrameTransformer.point(
        from: AnnotationFrameTransformer.rotateUnitPoint(startUnitBefore, clockwise: true),
        in: arrowAfter.frame
    )
    let rotatedEnd = AnnotationFrameTransformer.point(
        from: AnnotationFrameTransformer.rotateUnitPoint(endUnitBefore, clockwise: true),
        in: arrowAfter.frame
    )
    try expectNearlyEqual(
        AnnotationFrameTransformer.point(from: arrowAfter.startUnitPoint, in: arrowAfter.frame),
        rotatedStart,
        message: "回転後の矢印開始点の端点座標が不正です"
    )
    try expectNearlyEqual(
        AnnotationFrameTransformer.point(from: arrowAfter.endUnitPoint, in: arrowAfter.frame),
        rotatedEnd,
        message: "回転後の矢印終了点の端点座標が不正です"
    )

    let modelRedactionCheck = try makeEditorModel(image: testImage(width: 120, height: 120), fileName: "redaction-default")
    modelRedactionCheck.currentColorHex = "#00FF00"
    modelRedactionCheck.addAnnotation(
        kind: .redaction,
        frame: CGRect(x: 10, y: 10, width: 20, height: 20),
        start: CGPoint(x: 10, y: 10),
        end: CGPoint(x: 20, y: 10)
    )
    guard let redaction = modelRedactionCheck.annotations.last else {
        throw CheckFailure.failed("墨消し注釈を取得できません")
    }
    try expect(redaction.colorHex == "#000000", "墨消しは新規作成時に黒固定でありません")
    try expect(redaction.fillOpacity == 1, "墨消しは新規作成時に完全不透明でありません")
    modelRedactionCheck.applyColor("#FFFFFF")
    try expect(
        modelRedactionCheck.annotations.last?.colorHex == "#000000",
        "墨消しの色を変更できてしまいます"
    )

    let rotationModel = try makeEditorModel(
        image: testImage(width: 120, height: 80),
        fileName: "rotation-undo"
    )
    rotationModel.addAnnotation(
        kind: .rectangle,
        frame: CGRect(x: 10, y: 20, width: 30, height: 20)
    )
    rotationModel.rotateClockwise()
    try expect(rotationModel.imagePixelSize == CGSize(width: 80, height: 120), "右回転後の画像サイズが不正です")
    try expect(rotationModel.annotations.first?.frame == CGRect(x: 40, y: 10, width: 20, height: 30), "右回転後の注釈位置が不正です")
    rotationModel.undo()
    try expect(rotationModel.imagePixelSize == CGSize(width: 120, height: 80), "回転のUndoで画像サイズを復元できません")
    rotationModel.redo()
    try expect(rotationModel.imagePixelSize == CGSize(width: 80, height: 120), "回転のRedoで画像サイズを復元できません")

    let cropModel = try makeEditorModel(
        image: testImage(width: 120, height: 80),
        fileName: "crop-undo"
    )
    cropModel.addAnnotation(
        kind: .ellipse,
        frame: CGRect(x: 30, y: 20, width: 50, height: 40)
    )
    cropModel.applyCrop(to: CGRect(x: 20, y: 10, width: 80, height: 60))
    try expect(cropModel.imagePixelSize == CGSize(width: 80, height: 60), "クロップ後の画像サイズが不正です")
    try expect(cropModel.annotations.first?.frame == CGRect(x: 10, y: 10, width: 50, height: 40), "クロップ後の注釈位置が不正です")
    cropModel.undo()
    try expect(cropModel.imagePixelSize == CGSize(width: 120, height: 80), "クロップのUndoで画像サイズを復元できません")

    let maskCropModel = try makeEditorModel(
        image: testImage(width: 120, height: 80),
        fileName: "mask-crop"
    )
    maskCropModel.addAnnotation(
        kind: .blur,
        frame: CGRect(x: 10, y: 5, width: 60, height: 50)
    )
    maskCropModel.applyCrop(to: CGRect(x: 30, y: 20, width: 70, height: 50))
    try expect(
        maskCropModel.annotations.first?.frame == CGRect(x: 0, y: 0, width: 40, height: 35),
        "クロップ後のマスク範囲が交差部分へ切り詰められていません"
    )

    let magnifierModel = try makeEditorModel(
        image: testImage(width: 640, height: 480),
        fileName: "magnifier"
    )
    magnifierModel.addAnnotation(
        kind: .magnifier,
        frame: CGRect(x: 80, y: 60, width: 100, height: 70)
    )
    guard let storedMagnifier = magnifierModel.annotations.first else {
        throw CheckFailure.failed("作成したルーペ注釈を取得できません")
    }
    try expect(storedMagnifier.frame.width == storedMagnifier.frame.height, "ルーペの元領域が円形ではありません")
    try expect(
        CGRect(origin: .zero, size: magnifierModel.imagePixelSize)
            .contains(MagnifierGeometry.destinationFrame(for: storedMagnifier)),
        "ルーペの拡大円が初期状態で画像外にあります"
    )
    let destinationBeforeMovingSource = MagnifierGeometry.destinationFrame(for: storedMagnifier)
    magnifierModel.setFrame(
        storedMagnifier.frame.offsetBy(dx: 24, dy: 18),
        for: storedMagnifier.id
    )
    guard let movedMagnifier = magnifierModel.annotations.first else {
        throw CheckFailure.failed("移動後のルーペ注釈を取得できません")
    }
    try expect(
        movedMagnifier.frame == storedMagnifier.frame.offsetBy(dx: 24, dy: 18),
        "ルーペの起点を移動できません"
    )
    try expect(
        MagnifierGeometry.destinationFrame(for: movedMagnifier) == destinationBeforeMovingSource,
        "ルーペの起点移動で拡大先まで移動しています"
    )
    magnifierModel.applyMagnification(2.5)
    try expect(
        magnifierModel.annotations.first?.magnification == 2.5,
        "ルーペの倍率を変更できません"
    )
    try expect(
        MagnifierGeometry.rotatedOffset(CGSize(width: 100, height: 40), clockwise: true)
            == CGSize(width: -40, height: 100),
        "画像回転時のルーペ移動量が不正です"
    )

}

Task { @MainActor in
    do {
        try runChecks()
        print("All core checks passed")
        exit(0)
    } catch {
        fputs("Core check failed: \(error)\n", stderr)
        exit(1)
    }
}
dispatchMain()
