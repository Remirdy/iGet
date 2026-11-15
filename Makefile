# Makefile — iGet Proje Yardımcı Komutları
# Kullanım: make <hedef>
#   make help          # Bu yardım mesajını göster
#   make generate      # XcodeGen ile .xcodeproj üret
#   make build         # Debug derle
#   make release       # Release derle + arşivle
#   make test          # Testleri çalıştır
#   make clean         # Build dizinini temizle
#   make open          # Xcode'da aç
#   make lint          # SwiftLint çalıştır
#   make format        # SwiftFormat çalıştır

SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT      := iGet.xcodeproj
SCHEME       := iGet
BUILD_DIR    := build
SCRIPTS_DIR  := scripts

# ─────────────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Bu yardım mesajını göster
	@echo ""
	@echo "  iGet — Makefile Komutları"
	@echo "  ─────────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ── Proje Üretimi ─────────────────────────────────────────────────────────────

.PHONY: generate
generate: ## XcodeGen ile iGet.xcodeproj üret
	@echo "▶ XcodeGen çalıştırılıyor..."
	@chmod +x $(SCRIPTS_DIR)/generate.sh
	@$(SCRIPTS_DIR)/generate.sh

# ── Derleme ───────────────────────────────────────────────────────────────────

.PHONY: build
build: check-project ## Debug derle
	@echo "▶ Debug derleme..."
	@chmod +x $(SCRIPTS_DIR)/build.sh
	@$(SCRIPTS_DIR)/build.sh

.PHONY: release
release: check-project ## Release derle ve arşivle
	@echo "▶ Release derleme + arşivleme..."
	@chmod +x $(SCRIPTS_DIR)/build.sh
	@$(SCRIPTS_DIR)/build.sh --release

.PHONY: release-notarize
release-notarize: check-project ## Release derle, arşivle ve notarizasyon yap
	@chmod +x $(SCRIPTS_DIR)/build.sh
	@$(SCRIPTS_DIR)/build.sh --release --notarize

# ── Test ──────────────────────────────────────────────────────────────────────

.PHONY: test
test: check-project ## Tüm testleri çalıştır
	@echo "▶ Testler çalıştırılıyor..."
	@chmod +x $(SCRIPTS_DIR)/build.sh
	@$(SCRIPTS_DIR)/build.sh --test

# ── Temizlik ──────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Build dizinini temizle
	@echo "▶ Temizleniyor..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ $(BUILD_DIR) temizlendi"

.PHONY: clean-all
clean-all: clean ## Build + .xcodeproj yedeklerini temizle
	@rm -rf $(PROJECT).bak.*
	@echo "✓ Tüm geçici dosyalar temizlendi"

# ── Xcode ─────────────────────────────────────────────────────────────────────

.PHONY: open
open: check-project ## Xcode'da projeyi aç
	@open $(PROJECT)

.PHONY: check-project
check-project:
	@if [ ! -d "$(PROJECT)" ]; then \
		echo "⚠ $(PROJECT) bulunamadı — generate çalıştırılıyor..."; \
		$(MAKE) generate; \
	fi

# ── Kod Kalitesi ──────────────────────────────────────────────────────────────

.PHONY: lint
lint: ## SwiftLint ile kod kalitesi kontrolü
	@if command -v swiftlint &>/dev/null; then \
		echo "▶ SwiftLint çalıştırılıyor..."; \
		swiftlint lint --config .swiftlint.yml 2>/dev/null || swiftlint lint; \
	else \
		echo "⚠ SwiftLint bulunamadı: brew install swiftlint"; \
	fi

.PHONY: format
format: ## SwiftFormat ile kod biçimlendirme
	@if command -v swiftformat &>/dev/null; then \
		echo "▶ SwiftFormat çalıştırılıyor..."; \
		swiftformat . --swiftversion 5.9; \
	else \
		echo "⚠ SwiftFormat bulunamadı: brew install swiftformat"; \
	fi

# ── Araç Kurulumu ─────────────────────────────────────────────────────────────

.PHONY: setup
setup: ## Geliştirme araçlarını Homebrew ile kur
	@echo "▶ Geliştirme araçları kuruluyor..."
	@brew install xcodegen swiftlint swiftformat xcbeautify 2>/dev/null || true
	@echo "✓ Araçlar kuruldu"

# ── Bilgi ─────────────────────────────────────────────────────────────────────

.PHONY: info
info: ## Proje bilgilerini göster
	@echo ""
	@echo "  Proje   : iGet"
	@echo "  Bundle  : com.twobitdev.iGet"
	@echo "  Platform: macOS 14.0+"
	@echo "  Swift   : 5.9"
	@echo "  Xcode   : $$(xcodebuild -version 2>/dev/null | head -1 || echo 'bulunamadı')"
	@echo "  XcodeGen: $$(xcodegen version 2>/dev/null || echo 'kurulu değil')"
	@echo ""
