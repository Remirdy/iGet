#!/usr/bin/env bash
# scripts/generate.sh
# iGet — XcodeGen ile .xcodeproj üretimi
#
# Kullanım:
#   chmod +x scripts/generate.sh
#   ./scripts/generate.sh
#
# Gereksinim: brew install xcodegen
# XcodeGen: https://github.com/yonaskolb/XcodeGen

set -euo pipefail

# ── Renkler ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${BLUE}▶${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✗${RESET} $*" >&2; }

# ── Proje kökünü bul ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo -e "\n${BOLD}iGet — Xcode Proje Üretici${RESET}"
echo "──────────────────────────────────────"

# ── XcodeGen kurulu mu? ───────────────────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
    error "XcodeGen bulunamadı."
    echo ""
    echo "  Homebrew ile kurun:"
    echo "    brew install xcodegen"
    echo ""
    echo "  Veya Mint ile:"
    echo "    mint install yonaskolb/XcodeGen"
    exit 1
fi

XCODEGEN_VERSION=$(xcodegen version 2>/dev/null || echo "bilinmiyor")
log "XcodeGen sürümü: ${XCODEGEN_VERSION}"

# ── project.yml kontrolü ─────────────────────────────────────────────────────
if [[ ! -f "project.yml" ]]; then
    error "project.yml bulunamadı: ${PROJECT_ROOT}/project.yml"
    exit 1
fi

# ── Mevcut .xcodeproj'u yedekle ──────────────────────────────────────────────
XCODEPROJ="iGet.xcodeproj"
if [[ -d "${XCODEPROJ}" ]]; then
    BACKUP="${XCODEPROJ}.bak.$(date +%Y%m%d_%H%M%S)"
    warn "Mevcut ${XCODEPROJ} yedekleniyor → ${BACKUP}"
    mv "${XCODEPROJ}" "${BACKUP}"
fi

# ── XcodeGen çalıştır ────────────────────────────────────────────────────────
log "XcodeGen çalıştırılıyor..."
xcodegen generate \
    --spec project.yml \
    --project . \
    --use-cache

success "iGet.xcodeproj oluşturuldu!"

# ── Proje yapısını özet göster ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}Oluşturulan dosyalar:${RESET}"
find "${XCODEPROJ}" -name "*.pbxproj" -o -name "*.xcscheme" 2>/dev/null | sort | while read -r f; do
    echo "  ${f}"
done

echo ""
echo -e "${BOLD}Sonraki adım:${RESET}"
echo "  Projeyi Xcode'da açmak için:"
echo "    open iGet.xcodeproj"
echo ""
echo "  xcodebuild ile derlemek için:"
echo "    ./scripts/build.sh"
echo ""
