import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case system
    case es
    case en
    case fr
    case de
    case pt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Auto"
        case .es: "Español"
        case .en: "English"
        case .fr: "Français"
        case .de: "Deutsch"
        case .pt: "Português"
        }
    }

    var flag: String {
        switch self {
        case .system: "🌐"
        case .es: "🇪🇸"
        case .en: "🇬🇧"
        case .fr: "🇫🇷"
        case .de: "🇩🇪"
        case .pt: "🇵🇹"
        }
    }

    var resolved: AppLanguage {
        guard self == .system else { return self }
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("es") { return .es }
        if preferred.hasPrefix("fr") { return .fr }
        if preferred.hasPrefix("de") { return .de }
        if preferred.hasPrefix("pt") { return .pt }
        return .en
    }
}
