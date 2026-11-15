// QuickNoteWidget.swift
// iGet — OverlayEngine/Widgets
//
// Masaüstünde her zaman görünür, etkileşimli hızlı not widget'ı.
// Notlar App Group (SharedStorage) üzerinden kaydedilir.
//
// Özellikler:
//   • Çok satırlı metin girişi (TextEditor)
//   • Markdown-lite biçimlendirme (kalın, italik, kod)
//   • Karakter/satır sayacı
//   • Auto-save (debounce: 0.5s)
//   • Silme onayı
//   • Renk tema desteği (WidgetTheme)
//
// Target Membership: iGet
//
// Organization: TwoBit-Dev

import SwiftUI
import Combine

// MARK: - QuickNoteViewModel

@MainActor
public final class QuickNoteViewModel: ObservableObject {

    // MARK: Published

    @Published public var content: String = ""
    @Published public var isEditing: Bool = false
    @Published public private(set) var isSaving: Bool = false
    @Published public var showClearConfirm: Bool = false

    // MARK: Computed

    public var characterCount: Int { content.count }
    public var lineCount:      Int { content.components(separatedBy: "\n").count }
    public var wordCount:      Int { content.split { $0.isWhitespace }.count }
    public var isEmpty:        Bool { content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()
    private let saveDebounce: TimeInterval

    // MARK: Init

    public init(debounce: TimeInterval = 0.5) {
        self.saveDebounce = debounce
        load()
        setupAutoSave()
    }

    // MARK: - Persistence

    /// SharedStorage'dan notu yükler.
    public func load() {
        content = SharedStorage.shared.quickNoteContent
    }

    /// Notu SharedStorage'a yazar.
    public func save() {
        isSaving = true
        SharedStorage.shared.saveQuickNote(content)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isSaving = false
        }
    }

    /// İçeriği temizler ve kaydeder.
    public func clearContent() {
        content = ""
        save()
        showClearConfirm = false
    }

    // MARK: - Auto-Save

    private func setupAutoSave() {
        $content
            .dropFirst()                               // İlk load'u atla
            .debounce(for: .seconds(saveDebounce), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.save() }
            .store(in: &cancellables)
    }

    // MARK: - Formatting Helpers

    /// Seçili metne markdown biçimlendirmesi uygular.
    /// (NSTextView integration için kullanılır — macOS)
    public func applyFormat(_ format: TextFormat, to textView: NSTextView) {
        guard let range = textView.selectedRanges.first as? NSRange,
              range.length > 0,
              let selection = Range(range, in: content) else { return }

        let selected = String(content[selection])
        let formatted: String

        switch format {
        case .bold:          formatted = "**\(selected)**"
        case .italic:        formatted = "_\(selected)_"
        case .code:          formatted = "`\(selected)`"
        case .strikethrough: formatted = "~~\(selected)~~"
        }

        content.replaceSubrange(selection, with: formatted)
    }

    public enum TextFormat {
        case bold, italic, code, strikethrough
    }
}

// MARK: - QuickNoteWidgetView

/// Overlay katmanında gösterilen etkileşimli not widget'ı.
public struct QuickNoteWidgetView: View {

    // MARK: Properties

    public let config: WidgetConfig
    @Environment(\.widgetTheme) private var theme
    @StateObject private var vm = QuickNoteViewModel()
    @FocusState private var isFocused: Bool

    // MARK: Body

    public var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                Divider().opacity(0.2)

                editorArea
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                Divider().opacity(0.2)

                footer
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .padding(.top, 4)
            }
        }
        .frame(width: config.size.size.width, height: config.size.size.height)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .shadow(
            color: .black.opacity(theme.showShadow ? 0.25 : 0),
            radius: theme.shadowRadius, x: 0, y: 4
        )
        .confirmationDialog(
            "Notu Temizle",
            isPresented: $vm.showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Temizle", role: .destructive) { vm.clearContent() }
            Button("İptal",   role: .cancel)      { }
        } message: {
            Text("Tüm not içeriği silinecek. Bu işlem geri alınamaz.")
        }
    }

    // MARK: - Subviews

    private var background: some View {
        Group {
            if theme.blurBackground {
                VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
            } else {
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(theme.opacity * 0.9))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            // İkon
            Image(systemName: "note.text")
                .foregroundStyle(theme.accentColor)
                .font(.system(size: 13, weight: .semibold))

            // Başlık
            Text(config.title ?? "Hızlı Not")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            // Araç çubuğu
            HStack(spacing: 4) {
                // Format butonları (yalnızca düzenleme modunda)
                if vm.isEditing {
                    FormatButton(symbol: "bold",          label: "Kalın")      { }
                    FormatButton(symbol: "italic",        label: "İtalik")     { }
                    FormatButton(symbol: "chevron.left.forwardslash.chevron.right", label: "Kod") { }
                }

                // Kaydetme göstergesi
                if vm.isSaving {
                    Group {
                        if #available(macOS 15.0, *) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .symbolEffect(.rotate, isActive: vm.isSaving)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(vm.isSaving ? 360 : 0))
                                .animation(.linear(duration: 1).repeatForever(autoreverses: false),
                                           value: vm.isSaving)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Temizle butonu
                Button {
                    if vm.isEmpty { return }
                    vm.showClearConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(vm.isEmpty ? .tertiary : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(vm.isEmpty)
                .help("Notu temizle")
            }
        }
    }

    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            // Boş durum placeholder
            if vm.isEmpty && !isFocused {
                Text("Bir şeyler yaz…")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
                    .padding(.leading, 4)
                    .allowsHitTesting(false)
            }

            // Metin editörü
            TextEditor(text: $vm.content)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.primary)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .focused($isFocused)
                .onChange(of: isFocused) { _, focused in
                    vm.isEditing = focused
                }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            // İstatistikler
            Label("\(vm.wordCount) kelime", systemImage: "textformat.abc")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            Text("·")
                .foregroundStyle(.quaternary)
                .font(.system(size: 10))

            Label("\(vm.lineCount) satır", systemImage: "list.bullet")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            Spacer()

            // Karakter sayacı
            Text("\(vm.characterCount)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.quaternary)

            // Kayıt durumu noktası
            Circle()
                .fill(vm.isSaving ? theme.accentColor : .clear)
                .frame(width: 5, height: 5)
                .animation(.easeInOut(duration: 0.3), value: vm.isSaving)
        }
    }
}

// MARK: - FormatButton

private struct FormatButton: View {
    let symbol: String
    let label:  String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Preview

#if DEBUG && canImport(XcodePreview)
#Preview("QuickNoteWidget") {
    QuickNoteWidgetView(config: .quickNote())
        .environment(\.widgetTheme, .default)
        .frame(width: 300, height: 200)
        .background(.black)
}

#Preview("QuickNoteWidget — Dark") {
    QuickNoteWidgetView(config: .quickNote())
        .environment(\.widgetTheme, .dark)
        .frame(width: 300, height: 200)
        .preferredColorScheme(.dark)
        .background(.black)
}
#endif
