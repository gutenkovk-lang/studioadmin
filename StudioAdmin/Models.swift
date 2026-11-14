import Foundation
import SwiftUI

// MARK: - Клиент

struct Client: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var phone: String = ""
    var note: String = ""
    var createdAt = Date()

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

// MARK: - Зал

struct Hall: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var hourlyRate: Double
    var colorIndex: Int = 0

    static let palette: [Color] = [.indigo, .teal, .orange, .pink, .green, .brown, .blue, .purple]

    var color: Color {
        Hall.palette[abs(colorIndex) % Hall.palette.count]
    }
}

// MARK: - Аренда

struct Rental: Identifiable, Codable, Hashable {
    var id = UUID()
    var hallID: UUID
    var hallName: String
    var clientID: UUID?
    var clientName: String
    var start: Date
    var plannedEnd: Date
    var finishedAt: Date? = nil
    var price: Double
    /// Процент администратора фиксируется в момент аренды,
    /// поэтому смена процента в настройках не меняет прошлые записи.
    var commissionPercent: Double
    var isPaid: Bool = true
    var alarmFired: Bool = false

    var isActive: Bool { finishedAt == nil }
    var earning: Double { price * commissionPercent / 100 }
    var billedMinutes: Int { max(Int((plannedEnd.timeIntervalSince(start) / 60).rounded()), 0) }
}

// MARK: - Настройки

enum Melody: String, Codable, CaseIterable, Identifiable {
    case chime
    case harp
    case signal

    var id: String { rawValue }
    var fileName: String { rawValue + ".wav" }

    var title: String {
        switch self {
        case .chime: return "Перезвон"
        case .harp: return "Арфа"
        case .signal: return "Сигнал"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var commissionPercent: Double = 10
    var currencySymbol: String = "₽"
    var melody: Melody = .chime
    var vibration: Bool = true
    /// За сколько минут до конца прислать предупреждение (0 — выключено).
    var warnMinutes: Int = 5
    var defaultDuration: Int = 60
}
