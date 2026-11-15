#!/usr/bin/env bash
# scripts/build.sh
# iGet — xcodebuild CI/CD Script
#
# Kullanım:
#   chmod +x scripts/build.sh
#   ./scripts/build.sh                    # Debug derle
#   ./scripts/build.sh --release          # Release derle + arşivle
#   ./scripts/build.sh --test             # Test çalıştır
#   ./scripts/build.sh --clean            # Temiz derleme
#   ./scripts/build.sh --release --notarize  # İmzala + notarizasyon
#
# Gereksinimler:
#   • Xcode 15.0+
#   • xcodebuild (Xcode Command Line Tools)
#   • iGet.xcodeproj (./scripts/generate.sh ile oluştur)
#   • Release için: Apple geliştirici hesabı + imzalama sertifikası

set -euo pipefail

# ── Renkler ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${BLUE}[$(date +%H:%M:%S)]${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✗ HATA:${RESET} $*" >&2; }
step()    { echo -e "\n${CYAN}${BOLD}━━ $* ━━${RESET}"; }

# ── Argüman Ayrıştırma ────────────────────────────────────────────────────────
BUILD_CONFIG="Debug"
RUN_TESTS=false
CLEAN_BUILD=false
ARCHIVE=false
NOTARIZE=false

for arg in "$@"; do
    case "${arg}" in
        --release)   BUILD_CONFIG="Release"; ARCHIVE=true ;;
        --test)      RUN_TESTS=true ;;
        --clean)     CLEAN_BUILD=true ;;
        --notarize)  NOTARIZE=true ;;
        --help|-h)
            echo "Kullanım: $0 [--release] [--test] [--clean] [--notarize]"
            exit 0 ;;
    esac
done

# ── Dizin Kurulumu ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

BUILD_DIR="${PROJECT_ROOT}/build"
ARCHIVE_PATH="${BUILD_DIR}/iGet.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
DERIVED_DATA="${BUILD_DIR}/DerivedData"

mkdir -p "${BUILD_DIR}"

# ── Temel Xcodebuild Parametreleri ───────────────────────────────────────────
XCODEPROJ="iGet.xcodeproj"
SCHEME="iGet"
PLATFORM="macOS"

XCODEBUILD_BASE=(
    xcodebuild
    -project  "${XCODEPROJ}"
    -scheme   "${SCHEME}"
    -configuration "${BUILD_CONFIG}"
    -derivedDataPath "${DERIVED_DATA}"
    -destination "platform=${PLATFORM}"
)

# ── Başlık ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║      iGet — xcodebuild CI Script     ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""
log "Proje : ${PROJECT_ROOT}"
log "Şema  : ${SCHEME}"
log "Config: ${BUILD_CONFIG}"
log "Çıktı : ${BUILD_DIR}"
echo ""

# ── Ortam Kontrolleri ─────────────────────────────────────────────────────────
step "Ortam Kontrolü"

# Xcode varlığı
XCODE_PATH=$(xcode-select -p 2>/dev/null || echo "")
if [[ -z "${XCODE_PATH}" ]]; then
    error "Xcode Command Line Tools bulunamadı."
    echo "  xcode-select --install"
    exit 1
fi
success "Xcode: $(xcodebuild -version | head -1)"

# .xcodeproj varlığı
if [[ ! -d "${XCODEPROJ}" ]]; then
    warn "${XCODEPROJ} bulunamadı — XcodeGen çalıştırılıyor..."
    if command -v xcodegen &>/dev/null; then
        ./scripts/generate.sh
    else
        error "XcodeGen yok ve ${XCODEPROJ} bulunamadı."
        echo "  brew install xcodegen && ./scripts/generate.sh"
        exit 1
    fi
fi
success ".xcodeproj hazır"

# Swift sürümü
SWIFT_VERSION=$(swift --version 2>/dev/null | head -1 || echo "bilinmiyor")
log "Swift: ${SWIFT_VERSION}"

# ── Temizleme (isteğe bağlı) ─────────────────────────────────────────────────
if [[ "${CLEAN_BUILD}" == true ]]; then
    step "Temizleme"
    log "DerivedData temizleniyor..."
    "${XCODEBUILD_BASE[@]}" clean | xcpretty 2>/dev/null || "${XCODEBUILD_BASE[@]}" clean
    rm -rf "${DERIVED_DATA}"
    success "Temizleme tamamlandı"
fi

# ── Derleme ───────────────────────────────────────────────────────────────────
step "Derleme (${BUILD_CONFIG})"
BUILD_START=$(date +%s)

# xcpretty varsa güzel çıktı, yoksa ham xcodebuild
FORMATTER=""
if command -v xcpretty &>/dev/null; then
    FORMATTER="| xcpretty --color"
fi

log "xcodebuild build başlatılıyor..."

if eval "${XCODEBUILD_BASE[*]} build ${FORMATTER}"; then
    BUILD_END=$(date +%s)
    BUILD_ELAPSED=$((BUILD_END - BUILD_START))
    success "Derleme tamamlandı (${BUILD_ELAPSED}s)"
else
    error "Derleme başarısız!"
    exit 1
fi

# ── Testler (isteğe bağlı) ───────────────────────────────────────────────────
if [[ "${RUN_TESTS}" == true ]]; then
    step "Testler"
    log "Unit testler çalıştırılıyor..."

    if eval "${XCODEBUILD_BASE[*]} test ${FORMATTER}"; then
        success "Testler geçti ✓"
    else
        error "Testler başarısız!"
        exit 1
    fi
fi

# ── Arşivleme (Release) ───────────────────────────────────────────────────────
if [[ "${ARCHIVE}" == true ]]; then
    step "Arşivleme"
    log "Arşiv oluşturuluyor: ${ARCHIVE_PATH}"

    ARCHIVE_ARGS=(
        "${XCODEBUILD_BASE[@]}"
        archive
        -archivePath "${ARCHIVE_PATH}"
        OTHER_CODE_SIGN_FLAGS="--timestamp"
    )

    if eval "${ARCHIVE_ARGS[*]} ${FORMATTER}"; then
        success "Arşiv oluşturuldu: ${ARCHIVE_PATH}"
    else
        error "Arşivleme başarısız!"
        exit 1
    fi

    # ── Export ────────────────────────────────────────────────────────────────
    step "Export"
    mkdir -p "${EXPORT_PATH}"

    # ExportOptions.plist oluştur
    EXPORT_OPTIONS="${BUILD_DIR}/ExportOptions.plist"
    cat > "${EXPORT_OPTIONS}" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string></string>
</dict>
</plist>
PLIST

    if xcodebuild \
        -exportArchive \
        -archivePath "${ARCHIVE_PATH}" \
        -exportPath  "${EXPORT_PATH}" \
        -exportOptionsPlist "${EXPORT_OPTIONS}"; then
        success "Export tamamlandı: ${EXPORT_PATH}"
    else
        error "Export başarısız!"
        exit 1
    fi

    # ── Notarizasyon (isteğe bağlı) ───────────────────────────────────────────
    if [[ "${NOTARIZE}" == true ]]; then
        step "Notarizasyon"

        APP_PATH="${EXPORT_PATH}/iGet.app"
        ZIP_PATH="${BUILD_DIR}/iGet.zip"

        if [[ ! -d "${APP_PATH}" ]]; then
            error "iGet.app bulunamadı: ${APP_PATH}"
            exit 1
        fi

        # Zip'le
        log "Uygulama zip'leniyor..."
        ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

        # notarytool ile gönder
        log "Notarize gönderiliyor (Apple ID gerekli)..."
        warn "Aşağıdaki değerleri ortam değişkeni olarak ayarlayın:"
        warn "  export APPLE_ID='sizin@apple.id'"
        warn "  export APPLE_TEAM_ID='XXXXXXXXXX'"
        warn "  export APPLE_APP_PASSWORD='xxxx-xxxx-xxxx-xxxx'"

        if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
            xcrun notarytool submit "${ZIP_PATH}" \
                --apple-id    "${APPLE_ID}" \
                --team-id     "${APPLE_TEAM_ID}" \
                --password    "${APPLE_APP_PASSWORD}" \
                --wait \
                --output-format plist

            # Staple
            log "Ticket staple ediliyor..."
            xcrun stapler staple "${APP_PATH}"
            success "Notarizasyon tamamlandı ✓"
        else
            warn "Ortam değişkenleri eksik — notarizasyon atlandı."
        fi
    fi
fi

# ── Özet ──────────────────────────────────────────────────────────────────────
step "Özet"
echo ""
echo -e "  ${GREEN}Durum   :${RESET} ${BOLD}Başarılı ✓${RESET}"
echo -e "  ${GREEN}Config  :${RESET} ${BUILD_CONFIG}"
echo -e "  ${GREEN}Çıktı   :${RESET} ${BUILD_DIR}"

if [[ "${ARCHIVE}" == true && -d "${ARCHIVE_PATH}" ]]; then
    APP_SIZE=$(du -sh "${EXPORT_PATH}/iGet.app" 2>/dev/null | cut -f1 || echo "?")
    echo -e "  ${GREEN}App     :${RESET} ${EXPORT_PATH}/iGet.app (${APP_SIZE})"
fi
echo ""
