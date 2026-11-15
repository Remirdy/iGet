import Foundation
import Combine

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system, english = "en", turkish = "tr", german = "de"
    var id: String { rawValue }
    var name: String {
        switch self {
        case .system: return L10n.text("Follow system")
        case .english: return "English"
        case .turkish: return "Türkçe"
        case .german: return "Deutsch"
        }
    }
    static func resolve(_ selection: AppLanguage, preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard selection == .system else { return selection }
        return preferredLanguages.lazy.compactMap { tag in
            AppLanguage(rawValue: tag.replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map(String.init) ?? "")
        }.first(where: { $0 != .system }) ?? .english
    }
}

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    @Published private(set) var selection: AppLanguage = .system
    @Published private(set) var language: AppLanguage = .english
    private var localeObserver: NSObjectProtocol?
    var locale: Locale {
        Locale(identifier: language.rawValue + "_" + (Locale.current.region?.identifier ?? "US"))
    }
    init() {
        language = AppLanguage.resolve(.system)
        localeObserver = NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.selection == .system else { return }
            self.language = AppLanguage.resolve(.system)
        }
    }
    deinit { if let localeObserver { NotificationCenter.default.removeObserver(localeObserver) } }
    func select(_ value: AppLanguage) {
        let resolved = AppLanguage.resolve(value)
        guard selection != value || language != resolved else { return }
        selection = value
        language = resolved
    }
    func text(_ key: String, language: AppLanguage? = nil) -> String {
        let resolved = AppLanguage.resolve(language ?? self.language)
        guard let entry = LocalizationCatalog.entries[key] else { return key }
        switch resolved {
        case .turkish: return entry.tr
        case .german: return entry.de
        default: return key
        }
    }
    func format(_ key: String, arguments: [CVarArg], language: AppLanguage? = nil) -> String {
        let locale = language.map { Locale(identifier: AppLanguage.resolve($0).rawValue) } ?? self.locale
        return String(format: text(key, language: language), locale: locale, arguments: arguments)
    }
}

enum L10n {
    static func text(_ key: String) -> String { LocalizationManager.shared.text(key) }
    static func format(_ key: String, _ arguments: CVarArg...) -> String { LocalizationManager.shared.format(key, arguments: arguments) }
    static func count(_ count: Int, one: String, other: String) -> String { format(count == 1 ? one : other, count) }
}
