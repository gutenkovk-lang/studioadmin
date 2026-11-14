import SwiftUI

struct RentalRef: Identifiable {
    let id: UUID
}

// MARK: - Главный экран: залы

struct HallsView: View {
    @EnvironmentObject var store: Store
    @State private var hallToStart: Hall?
    @State private var detail: RentalRef?
    @State private var hallToEdit: Hall?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    TodaySummary()

                    if store.halls.isEmpty {
                        ContentUnavailableView(
                            "Нет залов",
                            systemImage: "square.grid.2x2",
                            description: Text("Добавьте залы в настройках.")
                        )
                        .padding(.top, 40)
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        ForEach(store.halls) { hall in
                            Button {
                                if let rental = store.activeRental(in: hall.id) {
                                    detail = RentalRef(id: rental.id)
                                } else {
                                    hallToStart = hall
                                }
                            } label: {
                                HallCard(hall: hall, rental: store.activeRental(in: hall.id))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    hallToEdit = hall
                                } label: {
                                    Label("Настроить зал", systemImage: "slider.horizontal.3")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Залы")
            .sheet(item: $hallToStart) { hall in
                StartRentalSheet(hall: hall)
                    .environmentObject(store)
            }
            .sheet(item: $detail) { ref in
                RentalDetailSheet(rentalID: ref.id)
                    .environmentObject(store)
            }
            .sheet(item: $hallToEdit) { hall in
                HallEditView(hall: hall)
                    .environmentObject(store)
            }
            .onChange(of: store.ringingID) { _, newValue in
                // Когда звучит сигнал, закрываем открытые окна, чтобы был виден экран «Время вышло».
                if newValue != nil {
                    hallToStart = nil
                    detail = nil
                    hallToEdit = nil
                }
            }
        }
    }
}

// MARK: - Сводка за сегодня

struct TodaySummary: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let today = store.rentals(in: Calendar.current.dateInterval(of: .day, for: Date()))
        let earning = today.filter { $0.isPaid }.reduce(0) { $0 + $1.earning }

        HStack(spacing: 12) {
            StatTile(title: "Заработок сегодня", value: store.money(earning))
            StatTile(title: "Аренд сегодня", value: "\(today.count)")
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Карточка зала

struct HallCard: View {
    @EnvironmentObject var store: Store
    let hall: Hall
    let rental: Rental?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(hall.color)
                    .frame(width: 10, height: 10)
                Text(hall.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            if let rental {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(rental.clientName)
                            .font(.subheadline)
                            .lineLimit(2)
                        Text("до \(Fmt.time.string(from: rental.plannedEnd))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    CountdownRing(rental: rental, size: 58, lineWidth: 5)
                }
            } else {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Свободен")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                        Text("\(store.money(hall.hourlyRate)) / час")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.tint)
                        .frame(width: 58, height: 58)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Кольцо обратного отсчёта

struct CountdownRing: View {
    let rental: Rental
    var size: CGFloat = 70
    var lineWidth: CGFloat = 6

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let total = max(rental.plannedEnd.timeIntervalSince(rental.start), 1)
            let left = rental.plannedEnd.timeIntervalSince(context.date)
            let progress = min(max(left / total, 0), 1)

            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        left > 300 ? Color.accentColor : Color.orange,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(Fmt.remaining(left))
                    .font(.system(size: size * 0.21, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(left > 0 ? Color.primary : Color.red)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, lineWidth + 4)
            }
            .frame(width: size, height: size)
        }
    }
}
