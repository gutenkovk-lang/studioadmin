import Foundation

enum Fmt {
    /// Остаток времени: «12:34», «1:05:09», а при просрочке «+02:10».
    static func remaining(_ interval: TimeInterval) -> String {
        let overtime = interval < 0
        let total = Int(abs(interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        let body = h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
        return overtime ? "+" + body : body
    }

    static func duration(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) мин" }
        if m == 0 { return "\(h) ч" }
        return "\(h) ч \(m) мин"
    }

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f
    }()

    static let dayTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    static func money(_ value: Double, symbol: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        f.groupingSeparator = "\u{00A0}"
        let number = f.string(from: NSNumber(value: value)) ?? "0"
        return number + "\u{00A0}" + symbol
    }

    static func telURL(_ phone: String) -> URL? {
        let allowed = phone.filter { $0.isNumber || $0 == "+" }
        guard !allowed.isEmpty else { return nil }
        return URL(string: "tel:" + allowed)
    }
}
