import SwiftUI

// MARK: - Новая аренда

struct StartRentalSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let hall: Hall

    @State private var clientID: UUID?
    @State private var newName = ""
    @State private var newPhone = ""
    @State private var minutes = 60
    @State private var price: Double = 0
    @State private var isPaid = true
    @State private var prepared = false

    private let presets = [30, 60, 90, 120, 180]

    private var canStart: Bool {
        clientID != nil || !newName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Клиент") {
                    NavigationLink {
                        ClientPicker(selection: $clientID)
                    } label: {
                        HStack {
                            Text("Клиент")
                            Spacer()
                            Text(store.client(clientID)?.name ?? "Новый")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if clientID == nil {
                        TextField("Имя", text: $newName)
                            .textContentType(.name)
                        TextField("Телефон", text: $newPhone)
                            .keyboardType(.phonePad)
                    }
                }

                Section {
                    Picker("Длительность", selection: $minutes) {
                        ForEach(presets, id: \.self) { value in
                            Text(shortLabel(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $minutes, in: 15...720, step: 15) {
                        Text(Fmt.duration(minutes: minutes))
                    }

                    LabeledContent(
                        "Окончание",
                        value: Fmt.time.string(from: Date().addingTimeInterval(Double(minutes) * 60))
                    )
                } header: {
                    Text("Время")
                }

                Section {
                    HStack {
                        Text("Стоимость")
                        Spacer()
                        TextField("0", value: $price, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                        Text(store.settings.currencySymbol)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("Оплачено", isOn: $isPaid)
                    LabeledContent(
                        "Мой процент (\(Int(store.settings.commissionPercent))%)",
                        value: store.money(price * store.settings.commissionPercent / 100)
                    )
                } header: {
                    Text("Оплата")
                } footer: {
                    Text("Стоимость считается по тарифу зала и пересчитывается при смене длительности. Её можно исправить вручную.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(hall.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Начать") { start() }
                        .disabled(!canStart)
                }
            }
            .onAppear {
                guard !prepared else { return }
                prepared = true
                minutes = store.settings.defaultDuration
                price = store.suggestedPrice(for: hall, minutes: minutes)
            }
            .onChange(of: minutes) { _, newValue in
                price = store.suggestedPrice(for: hall, minutes: newValue)
            }
        }
    }

    private func shortLabel(_ value: Int) -> String {
        switch value {
        case 30: return "30 м"
        case 60: return "1 ч"
        case 90: return "1,5 ч"
        case 120: return "2 ч"
        case 180: return "3 ч"
        default: return Fmt.duration(minutes: value)
        }
    }

    private func start() {
        var id = clientID
        var name = store.client(clientID)?.name ?? ""
        if id == nil {
            let client = store.addClient(name: newName, phone: newPhone)
            id = client.id
            name = client.name
        }
        store.startRental(hall: hall, clientID: id, clientName: name, minutes: minutes, price: price, isPaid: isPaid)
        dismiss()
    }
}

// MARK: - Выбор клиента

struct ClientPicker: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: UUID?
    @State private var query = ""

    var body: some View {
        List {
            Button {
                selection = nil
                dismiss()
            } label: {
                Label("Новый клиент", systemImage: "person.badge.plus")
            }

            ForEach(store.searchClients(query)) { client in
                Button {
                    selection = client.id
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.name)
                                .foregroundStyle(Color.primary)
                            if !client.phone.isEmpty {
                                Text(client.phone)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if selection == client.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Имя или телефон")
        .navigationTitle("Клиент")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Текущая аренда

struct RentalDetailSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let rentalID: UUID
    @State private var confirmFinish = false

    var body: some View {
        NavigationStack {
            Group {
                if let rental = store.rental(rentalID) {
                    content(rental)
                } else {
                    Color.clear
                }
            }
            .navigationTitle(store.rental(rentalID)?.hallName ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private func content(_ rental: Rental) -> some View {
        List {
            Section {
                VStack(spacing: 12) {
                    CountdownRing(rental: rental, size: 180, lineWidth: 10)
                    Text(rental.clientName)
                        .font(.title3.weight(.semibold))
                    Text("\(Fmt.time.string(from: rental.start)) – \(Fmt.time.string(from: rental.plannedEnd)) · \(Fmt.duration(minutes: rental.billedMinutes))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                HStack(spacing: 10) {
                    ForEach([15, 30, 60], id: \.self) { minutes in
                        Button {
                            store.extend(rental.id, minutes: minutes)
                        } label: {
                            Text("+\(Fmt.duration(minutes: minutes))")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } header: {
                Text("Продлить")
            } footer: {
                Text("При продлении стоимость увеличивается по тарифу зала.")
            }

            Section("Оплата") {
                HStack {
                    Text("Стоимость")
                    Spacer()
                    TextField(
                        "0",
                        value: Binding(
                            get: { store.rental(rentalID)?.price ?? 0 },
                            set: { store.setPrice(rentalID, $0) }
                        ),
                        format: .number
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    Text(store.settings.currencySymbol)
                        .foregroundStyle(.secondary)
                }
                Toggle(
                    "Оплачено",
                    isOn: Binding(
                        get: { store.rental(rentalID)?.isPaid ?? false },
                        set: { store.setPaid(rentalID, $0) }
                    )
                )
                LabeledContent(
                    "Мой процент (\(Int(rental.commissionPercent))%)",
                    value: store.money(rental.earning)
                )
            }

            if let client = store.client(rental.clientID), let url = Fmt.telURL(client.phone) {
                Section {
                    Link(destination: url) {
                        Label("Позвонить: \(client.phone)", systemImage: "phone")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmFinish = true
                } label: {
                    Text("Завершить аренду")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog("Завершить аренду сейчас?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Завершить", role: .destructive) {
                store.finish(rentalID)
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}
