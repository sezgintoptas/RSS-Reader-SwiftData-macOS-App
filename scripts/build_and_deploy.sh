#!/bin/bash
# RSS Reader — Build & Deploy Script
# Kullanım: bash scripts/build_and_deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_BUNDLE="$PROJECT_DIR/RSSReader.app"
BINARY_PATH="$PROJECT_DIR/.build/debug/RSSReader"

# AppVersion.swift'ten sürüm numarasını otomatik çek
VERSION=$(grep -o '"[0-9]*\.[0-9]*\.[0-9]*"' "$PROJECT_DIR/Sources/RSSReader/Utils/AppVersion.swift" | head -1 | tr -d '"')
if [ -z "$VERSION" ]; then
    echo "⚠️  Sürüm numarası bulunamadı, varsayılan kullanılıyor"
    VERSION="1.0.0"
fi
echo "📌 Sürüm: v$VERSION"

echo "🔨 [1/4] Build alınıyor..."
cd "$PROJECT_DIR"
swift build 2>&1 | tail -5

if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Build başarısız! Binary bulunamadı: $BINARY_PATH"
    exit 1
fi
echo "✅ Build tamamlandı"

echo "📦 [2/4] .app bundle oluşturuluyor..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Binary kopyala
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/RSSReader"
chmod +x "$APP_BUNDLE/Contents/MacOS/RSSReader"

# İkon kopyala
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Info.plist yaz (sürüm AppVersion.swift'ten otomatik alınır)
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>RSSReader</string>
    <key>CFBundleIdentifier</key>
    <string>com.sezgintoptas.rssreader</string>
    <key>CFBundleName</key>
    <string>RSSReader</string>
    <key>CFBundleDisplayName</key>
    <string>RSS Okuyucu</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ .app bundle oluşturuldu: $APP_BUNDLE"

echo "🚀 [3/4] /Applications klasörüne kopyalanıyor..."
sudo cp -Rp "$APP_BUNDLE" /Applications/RSSReader.app
echo "✅ /Applications/RSSReader.app kuruldu (v$VERSION)"

echo "🎉 [4/4] Uygulama başlatılıyor..."
open /Applications/RSSReader.app
