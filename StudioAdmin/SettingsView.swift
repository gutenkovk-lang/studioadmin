import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var editingHall: Hall?
    @State private var addingHall = false

    private let currencies = ["₽", "$", "€", "₸", "₴", "Br", "K"]
    private let warnOptions = [0, 5, 10, 15]
    private let durationOptions = [30, 60, 90, 120, 180]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $store.settings.commissionPercent, in: 0...100, step: 1) {
                        LabeledContent("Мой процент", value: "\(Int(store.settings.commissionPercent))%")
                    }
                    Picker("Валюта", selection: $store.settings.currencySymbol) {
                        ForEach(currencies, id: \.self) { symbol in
                            Text(symbol).tag(symbol)
                        }
                    }
                } header: {
                    Text("Заработок")
                } footer: {
                    Text("Процент применяется к новым арендам. В уже записанных остаётся тот, что действовал в момент аренды.")
                }

                Section {
                    Picker("Мелодия", selection: $store.settings.melody) {
                        ForEach(Melody.allCases) { melody in
                            Text(melody.title).tag(melody)
                        }
                    }
                    Toggle("Вибрация", isOn: $store.settings.vibration)
                    Picker("Предупредить заранее", selection: $store.settings.warnMinutes) {
                        ForEach(warnOptions, id: \.self) { value in
                            Text(value == 0 ? "Нет" : "За \(value) мин").tag(value)
                        }
                    }
                    Button("Проверить сигнал") {
                        AlarmManager.shared.preview(store.settings.melody, vibration: store.settings.vibration)
                    }
                } header: {
                    Text("Сигнал окончания")
                } footer: {
                    Text("Когда приложение свёрнуто, сигнал приходит уведомлением — разрешите уведомления для приложения в Настройках iPhone.")
                }

                Section("Аренда") {
                    Picker("Длительность по умолчанию", selection: $store.settings.defaultDuration) {
                        ForEach(durationOptions, id: \.self) { value in
                            Text(Fmt.duration(minutes: value)).tag(value)
                        }
                    }
                }

                Section {
                    ForEach(store.halls) { hall in
                        Button {
                            editingHall = hall
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(hall.color)
                                    .frame(width: 10, height: 10)
                                Text(hall.name)
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Text("\(store.money(hall.hourlyRate)) / ч")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        store.deleteHalls(at: offsets)
                    }

                    Button {
                        addingHall = true
                    } label: {
                        Label("Добавить зал", systemImage: "plus")
                    }
                } header: {
                    Text("Залы")
                } footer: {
                    Text("Смахните влево, чтобы удалить зал. Занятый зал удалить нельзя.")
                }

                Section("Данные") {
                    ShareLink(item: store.csvExport()) {
                        Label("Экспорт аренд (CSV)", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Настройки")
            .onChange(of: store.settings.melody) { _, newValue in
                AlarmManager.shared.preview(newValue, vibration: false)
            }
            .sheet(item: $editingHall) { hall in
                HallEditView(hall: hall)
                    .environmentObject(store)
            }
            .sheet(isPresented: $addingHall) {
                HallEditView(hall: nil)
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - Добавление и изменение зала

struct HallEditView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let hall: Hall?

    @State private var name = ""
    @State private var rate: Double = 1500
    @State private var colorIndex = 0
    @State private var prepared = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $name)
                    HStack {
                        Text("Цена за час")
                        Spacer()
                        TextField("0", value: $rate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                        Text(store.settings.currencySymbol)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Цвет") {
                    HStack(spacing: 0) {
                        ForEach(Hall.palette.indices, id: \.self) { index in
                            Button {
                                colorIndex = index
                            } label: {
                                Circle()
                                    .fill(Hall.palette[index])
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        if index == colorIndex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(hall == nil ? "Новый зал" : "Зал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard !prepared else { return }
                prepared = true
                if let hall {
                    name = hall.name
                    rate = hall.hourlyRate
                    colorIndex = hall.colorIndex
                } else {
                    colorIndex = store.halls.count % Hall.palette.count
                }
            }
        }
    }

    private func save() {
        var result = hall ?? Hall(name: "", hourlyRate: 0)
        result.name = name.trimmingCharacters(in: .whitespaces)
        result.hourlyRate = max(rate, 0)
        result.colorIndex = colorIndex
        store.saveHall(result)
        dismiss()
    }
}
