import SwiftUI
import Charts

enum Period: String, CaseIterable, Identifiable {
    case day = "День"
    case week = "Неделя"
    case month = "Месяц"
    case all = "Всё"

    var id: String { rawValue }

    var interval: DateInterval? {
        let calendar = Calendar.current
        switch self {
        case .day: return calendar.dateInterval(of: .day, for: Date())
        case .week: return calendar.dateInterval(of: .weekOfYear, for: Date())
        case .month: return calendar.dateInterval(of: .month, for: Date())
        case .all: return nil
        }
    }
}

struct DayStat: Identifiable {
    let day: Date
    let amount: Double
    var id: Date { day }
}

struct EarningsView: View {
    @EnvironmentObject var store: Store
    @State private var period: Period = .week

    var body: some View {
        NavigationStack {
            let items = store.rentals(in: period.interval)
            let paid = items.filter { $0.isPaid }
            let revenue = paid.reduce(0) { $0 + $1.price }
            let earning = paid.reduce(0) { $0 + $1.earning }
            let minutes = items.reduce(0) { $0 + $1.billedMinutes }
            let unpaid = items.filter { !$0.isPaid }.reduce(0) { $0 + $1.price }

            List {
                Section {
                    Picker("Период", selection: $period) {
                        ForEach(Period.allCases) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Мой заработок")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(store.money(earning))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .padding(.vertical, 6)

                    LabeledContent("Выручка студии", value: store.money(revenue))
                    LabeledContent("Аренд", value: "\(items.count)")
                    LabeledContent("Часов аренды", value: Fmt.duration(minutes: minutes))
                    if unpaid > 0 {
                        LabeledContent("Не оплачено", value: store.money(unpaid))
                            .foregroundStyle(.orange)
                    }
                }

                if period == .week || period == .month {
                    let stats = dailyStats(paid)
                    if !stats.isEmpty {
                        Section("По дням") {
                            Chart(stats) { stat in
                                BarMark(
                                    x: .value("День", stat.day, unit: .day),
                                    y: .value("Заработок", stat.amount)
                                )
                                .foregroundStyle(Color.accentColor.gradient)
                                .cornerRadius(4)
                            }
                            .frame(height: 170)
                            .padding(.vertical, 8)
                        }
                    }
                }

                Section("Аренды") {
                    if items.isEmpty {
                        Text("За этот период аренд нет")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(items) { rental in
                        RentalRow(rental: rental, showClient: true)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.deleteRental(rental.id)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                                Button {
                                    store.setPaid(rental.id, !rental.isPaid)
                                } label: {
                                    Label(rental.isPaid ? "Не оплачено" : "Оплачено", systemImage: "creditcard")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
            .navigationTitle("Заработок")
        }
    }

    private func dailyStats(_ rentals: [Rental]) -> [DayStat] {
        let calendar = Calendar.current
        var totals: [Date: Double] = [:]
        for rental in rentals {
            let day = calendar.startOfDay(for: rental.start)
            totals[day, default: 0] += rental.earning
        }
        return totals
            .map { DayStat(day: $0.key, amount: $0.value) }
            .sorted { $0.day < $1.day }
    }
}

/// Строка аренды в истории.
struct RentalRow: View {
    @EnvironmentObject var store: Store
    let rental: Rental
    let showClient: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(showClient ? rental.clientName : rental.hallName)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(store.money(rental.price))
                    .monospacedDigit()
                if rental.isPaid {
                    Text("+" + store.money(rental.earning))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.green)
                } else {
                    Text("не оплачено")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if showClient { parts.append(rental.hallName) }
        parts.append(Fmt.dayTime.string(from: rental.start))
        parts.append(Fmt.duration(minutes: rental.billedMinutes))
        if rental.isActive { parts.append("идёт") }
        return parts.joined(separator: " · ")
    }
}
