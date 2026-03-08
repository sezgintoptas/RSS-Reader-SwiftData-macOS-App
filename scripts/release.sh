#!/bin/bash

# RSS Reader Release Automation Script
# Bu script versiyonlama, release notlarını güncelleme ve GitHub'a push işlemlerini hızlandırır.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Renkler
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 RSS Reader Release Otomasyonu başlatılıyor...${NC}"

# 1. Mevcut versiyonu bul (hem git tag hem AppVersion.swift'ten)
CURRENT_TAG=$(git tag -l "v*" | sort -V | tail -n1)
CURRENT_CODE=$(grep -o '"[0-9]*\.[0-9]*\.[0-9]*"' Sources/RSSReader/Utils/AppVersion.swift | head -1 | tr -d '"')
echo -e "Git tag versiyonu : ${GREEN}${CURRENT_TAG:-Yok}${NC}"
echo -e "Kod versiyonu     : ${GREEN}${CURRENT_CODE:-Yok}${NC}"

if [ "$CURRENT_TAG" != "v$CURRENT_CODE" ] && [ -n "$CURRENT_TAG" ] && [ -n "$CURRENT_CODE" ]; then
    echo -e "${YELLOW}⚠️  Tag ($CURRENT_TAG) ve kod (v$CURRENT_CODE) uyumsuz!${NC}"
fi

# 2. Yeni versiyonu sor
read -p "Yeni versiyon numarası (Örn: v1.6.0): " NEW_VERSION

if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Hatalı versiyon formatı! Lütfen 'v1.x.x' şeklinde giriniz."
    exit 1
fi

VERSION_NUMBER="${NEW_VERSION#v}"  # v önekini kaldır (1.6.0)

# 3. AppVersion.swift güncelle
echo -e "${BLUE}🔄 AppVersion.swift güncelleniyor → $VERSION_NUMBER${NC}"
sed -i '' "s/static let current = \"[0-9]*\.[0-9]*\.[0-9]*\"/static let current = \"$VERSION_NUMBER\"/" Sources/RSSReader/Utils/AppVersion.swift
echo -e "${GREEN}✅ AppVersion.swift güncellendi${NC}"

# 4. Release Notlarını Al
echo -e "${BLUE}📝 Release notlarını girin (Bitirmek için Ctrl+D'ye basın veya boş bırakıp geçin):${NC}"
TEMP_NOTES="./.release_notes_temp"
cat > "$TEMP_NOTES"

# 5. RELEASE_NOTES.md Güncelle
echo -e "${BLUE}🔄 RELEASE_NOTES.md güncelleniyor...${NC}"

RELEASE_DATE=$(date +%Y-%m-%d)
cat << EOF > RELEASE_NOTES.new.md
## 🆕 $NEW_VERSION — $RELEASE_DATE

### ✨ Yenilikler
$(cat "$TEMP_NOTES" | sed 's/^/- /')

$(cat docs/RELEASE_NOTES.md)
EOF

mv RELEASE_NOTES.new.md docs/RELEASE_NOTES.md
rm "$TEMP_NOTES"

# 6. Git İşlemleri
echo -e "${BLUE}📦 Git işlemleri yapılıyor...${NC}"
git add Sources/RSSReader/Utils/AppVersion.swift docs/RELEASE_NOTES.md
git commit -m "release: $NEW_VERSION

- AppVersion.swift → $VERSION_NUMBER
- RELEASE_NOTES.md güncellendi"
git tag "$NEW_VERSION"

# 7. Push
echo -e "${BLUE}☁️ GitHub'a gönderiliyor...${NC}"
git push origin main
git push origin "$NEW_VERSION"

REPO_URL=$(git remote get-url origin | sed 's/.*github.com[:\\/]\(.*\)\.git/\1/')
echo -e "${GREEN}✅ Başarılı! $NEW_VERSION yayında.${NC}"
echo -e "📋 Release oluştur : https://github.com/$REPO_URL/releases/new?tag=$NEW_VERSION"
echo -e "⚙️  Actions takip  : https://github.com/$REPO_URL/actions"
