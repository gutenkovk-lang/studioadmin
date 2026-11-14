import Foundation
import SwiftUI

/// Все данные приложения. Хранятся на устройстве в одном JSON-файле.
@MainActor
final class Store: ObservableObject {
    @Published var clients: [Client] = [] { didSet { save() } }
    @Published var halls: [Hall] = [] { didSet { save() } }
    @Published var rentals: [Rental] = [] { didSet { save() } }
    @Published var settings = AppSettings() {
        didSet {
            save()
            if !loading && settings != oldValue { rescheduleAll() }
        }
    }
    /// Аренда, по которой прямо сейчас звучит сигнал.
    @Published var ringingID: UUID?

    private var loading = false
    private var timer: Timer?

    private struct Snapshot: Codable {
        var clients: [Client]
        var halls: [Hall]
        var rentals: [Rental]
        var settings: AppSettings
    }

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("studio-data.json")
    }

    init() {
        load()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    // MARK: Хранение

    private func save() {
        guard !loading else { return }
        let snapshot = Snapshot(clients: clients, halls: halls, rentals: rentals, settings: settings)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        loading = true
        defer { loading = false }
        if let data = try? Data(contentsOf: fileURL),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            clients = snapshot.clients
            halls = snapshot.halls
            rentals = snapshot.rentals
            settings = snapshot.settings
        } else {
            // По умолчанию 10 залов — названия, цены и цвета меняются в настройках
            // или долгим нажатием на карточку зала.
            halls = (1...10).map { number in
                Hall(name: "Зал \(number)", hourlyRate: 1500, colorIndex: (number - 1) % Hall.palette.count)
            }
        }
    }

    // MARK: Форматирование

    func money(_ value: Double) -> String {
        Fmt.money(value, symbol: settings.currencySymbol)
    }

    // MARK: Клиенты

    func client(_ id: UUID?) -> Client? {
        guard let id else { return nil }
        return clients.first { $0.id == id }
    }

    func searchClients(_ query: String) -> [Client] {
        let sorted = clients.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return sorted }
        let digits = q.filter { $0.isNumber }
        return sorted.filter { client in
            if client.name.localizedCaseInsensitiveContains(q) { return true }
            if !digits.isEmpty && client.phone.filter({ $0.isNumber }).contains(digits) { return true }
            return false
        }
    }

    @discardableResult
    func addClient(name: String, phone: String, note: String = "") -> Client {
        let client = Client(
            name: name.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            note: note
        )
        clients.append(client)
        return client
    }

    func updateClient(_ client: Client) {
        guard let i = clients.firstIndex(where: { $0.id == client.id }) else { return }
        clients[i] = client
        // Имя в уже созданных арендах обновляем тоже.
        for j in rentals.indices where rentals[j].clientID == client.id {
            rentals[j].clientName = client.name
        }
    }

    func deleteClient(_ id: UUID) {
        clients.removeAll { $0.id == id }
    }

    func rentals(of clientID: UUID) -> [Rental] {
        rentals.filter { $0.clientID == clientID }.sorted { $0.start > $1.start }
    }

    // MARK: Залы

    func saveHall(_ hall: Hall) {
        if let i = halls.firstIndex(where: { $0.id == hall.id }) {
            halls[i] = hall
        } else {
            halls.append(hall)
        }
    }

    /// Занятый зал удалить нельзя — сначала нужно завершить аренду.
    func deleteHalls(at offsets: IndexSet) {
        let ids = offsets.map { halls[$0].id }.filter { activeRental(in: $0) == nil }
        halls.removeAll { ids.contains($0.id) }
    }

    // MARK: Аренды

    func rental(_ id: UUID) -> Rental? {
        rentals.first { $0.id == id }
    }

    func activeRental(in hallID: UUID) -> Rental? {
        rentals.first { $0.hallID == hallID && $0.isActive }
    }

    func rentals(in interval: DateInterval?) -> [Rental] {
        let list: [Rental]
        if let interval {
            list = rentals.filter { interval.contains($0.start) }
        } else {
            list = rentals
        }
        return list.sorted { $0.start > $1.start }
    }

    func suggestedPrice(for hall: Hall, minutes: Int) -> Double {
        (hall.hourlyRate * Double(minutes) / 60).rounded()
    }

    func startRental(hall: Hall, clientID: UUID?, clientName: String, minutes: Int, price: Double, isPaid: Bool) {
        let now = Date()
        let rental = Rental(
            hallID: hall.id,
            hallName: hall.name,
            clientID: clientID,
            clientName: clientName,
            start: now,
            plannedEnd: now.addingTimeInterval(Double(minutes) * 60),
            price: price,
            commissionPercent: settings.commissionPercent,
            isPaid: isPaid
        )
        rentals.append(rental)
        AlarmManager.shared.schedule(for: rental, settings: settings)
    }

    /// Продление: время добавляется к плановому окончанию, стоимость — по тарифу зала.
    func extend(_ id: UUID, minutes: Int) {
        guard let i = rentals.firstIndex(where: { $0.id == id }) else { return }
        var rental = rentals[i]
        rental.plannedEnd = rental.plannedEnd.addingTimeInterval(Double(minutes) * 60)
        rental.alarmFired = false
        if let hall = halls.first(where: { $0.id == rental.hallID }) {
            rental.price += suggestedPrice(for: hall, minutes: minutes)
        }
        rentals[i] = rental
        if ringingID == id { silence() }
        AlarmManager.shared.schedule(for: rental, settings: settings)
    }

    func finish(_ id: UUID) {
        guard let i = rentals.firstIndex(where: { $0.id == id }) else { return }
        rentals[i].finishedAt = Date()
        rentals[i].alarmFired = true
        if ringingID == id { silence() }
        AlarmManager.shared.cancel(for: id)
    }

    func setPaid(_ id: UUID, _ paid: Bool) {
        guard let i = rentals.firstIndex(where: { $0.id == id }) else { return }
        rentals[i].isPaid = paid
    }

    func setPrice(_ id: UUID, _ price: Double) {
        guard let i = rentals.firstIndex(where: { $0.id == id }) else { return }
        rentals[i].price = max(price, 0)
    }

    func deleteRental(_ id: UUID) {
        if ringingID == id { silence() }
        AlarmManager.shared.cancel(for: id)
        rentals.removeAll { $0.id == id }
    }

    // MARK: Сигнал

    func silence() {
        AlarmManager.shared.stopRinging()
        ringingID = nil
    }

    private func tick() {
        guard ringingID == nil else { return }
        let now = Date()
        guard let i = rentals.firstIndex(where: { $0.isActive && !$0.alarmFired && $0.plannedEnd <= now }) else { return }
        rentals[i].alarmFired = true
        ringingID = rentals[i].id
        AlarmManager.shared.startRinging(melody: settings.melody, vibration: settings.vibration)
    }

    private func rescheduleAll() {
        for rental in rentals where rental.isActive {
            AlarmManager.shared.schedule(for: rental, settings: settings)
        }
    }

    // MARK: Экспорт

    func csvExport() -> String {
        var lines = ["Дата;Зал;Клиент;Минут;Стоимость;Оплачено;Процент;Заработок"]
        for r in rentals.sorted(by: { $0.start < $1.start }) {
            let fields: [String] = [
                Fmt.dayTime.string(from: r.start),
                r.hallName,
                r.clientName,
                String(r.billedMinutes),
                String(Int(r.price)),
                r.isPaid ? "да" : "нет",
                String(Int(r.commissionPercent)),
                String(Int(r.isPaid ? r.earning : 0))
            ]
            lines.append(fields.joined(separator: ";"))
        }
        return lines.joined(separator: "\n")
    }
}
