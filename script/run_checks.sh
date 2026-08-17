#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/.build/checks"
OUTPUT_BINARY="$OUTPUT_DIR/core-checks"

mkdir -p "$OUTPUT_DIR"
/usr/bin/xcrun swiftc \
  -swift-version 5 \
  "$PROJECT_ROOT/Sources/GyazoCapture/Support/AppConstants.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Support/EditorStylePresets.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Models/AnnotationItem.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Models/AnnotationGeometry.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Support/AnnotationFrameTransformer.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Models/CollectionPreset.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Models/GyazoModels.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Services/GyazoClient.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Services/OAuthService.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Services/KeychainStore.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Services/ImageTransformService.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Services/MaskEffectRenderer.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Services/ImageCompositor.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Stores/SettingsStore.swift" \
  "$PROJECT_ROOT/Sources/GyazoCapture/Stores/EditorModel.swift" \
  "$PROJECT_ROOT/Checks/main.swift" \
  -framework AppKit \
  -framework AuthenticationServices \
  -framework CoreImage \
  -framework Security \
  -o "$OUTPUT_BINARY"

"$OUTPUT_BINARY"
