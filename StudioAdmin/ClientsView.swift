import SwiftUI

// MARK: - Список клиентов

struct ClientsView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var adding = false

    var body: some View {
        NavigationStack {
            let list = store.searchClients(query)

            List {
                ForEach(list) { client in
                    NavigationLink {
                        ClientDetailView(clientID: client.id)
                    } label: {
                        ClientRow(client: client, visits: store.rentals(of: client.id).count)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        store.deleteClient(list[index].id)
                    }
                }
            }
            .overlay {
                if store.clients.isEmpty {
                    ContentUnavailableView(
                        "Пока нет клиентов",
                        systemImage: "person.2",
                        description: Text("Клиенты добавляются при оформлении аренды или кнопкой «+».")
                    )
                } else if list.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Имя или телефон")
            .navigationTitle("Клиенты")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        adding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $adding) {
                ClientEditView(client: nil)
                    .environmentObject(store)
            }
        }
    }
}

struct Avatar: View {
    let initials: String
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(Color(.tertiarySystemFill))
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
    }
}

struct ClientRow: View {
    let client: Client
    let visits: Int

    var body: some View {
        HStack(spacing: 12) {
            Avatar(initials: client.initials)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                if !client.phone.isEmpty {
                    Text(client.phone)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if visits > 0 {
                Text("\(visits)")
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
    }
}

// MARK: - Карточка клиента

struct ClientDetailView: View {
    @EnvironmentObject var store: Store
    let clientID: UUID
    @State private var editing = false

    var body: some View {
        Group {
            if let client = store.client(clientID) {
                content(client)
            } else {
                ContentUnavailableView("Клиент удалён", systemImage: "person.slash")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ client: Client) -> some View {
        let history = store.rentals(of: client.id)
        let spent = history.filter { $0.isPaid }.reduce(0) { $0 + $1.price }

        return List {
            Section {
                VStack(spacing: 10) {
                    Avatar(initials: client.initials, size: 84)
                    Text(client.name)
                        .font(.title2.weight(.semibold))
                    Text("Клиент с \(Fmt.day.string(from: client.createdAt))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if !client.phone.isEmpty || !client.note.isEmpty {
                Section {
                    if let url = Fmt.telURL(client.phone) {
                        Link(destination: url) {
                            Label(client.phone, systemImage: "phone")
                        }
                    }
                    if !client.note.isEmpty {
                        Text(client.note)
                    }
                }
            }

            Section("Статистика") {
                LabeledContent("Посещений", value: "\(history.count)")
                LabeledContent("Оплачено всего", value: store.money(spent))
                if let last = history.first {
                    LabeledContent("Последний визит", value: Fmt.day.string(from: last.start))
                }
            }

            if !history.isEmpty {
                Section("История") {
                    ForEach(history) { rental in
                        RentalRow(rental: rental, showClient: false)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Изменить") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            ClientEditView(client: client)
                .environmentObject(store)
        }
    }
}

// MARK: - Добавление и изменение клиента

struct ClientEditView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let client: Client?

    @State private var name = ""
    @State private var phone = ""
    @State private var note = ""
    @State private var prepared = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Имя", text: $name)
                        .textContentType(.name)
                    TextField("Телефон", text: $phone)
                        .keyboardType(.phonePad)
                }
                Section("Заметка") {
                    TextField("Предпочтения, реквизит, скидка…", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(client == nil ? "Новый клиент" : "Клиент")
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
                if let client {
                    name = client.name
                    phone = client.phone
                    note = client.note
                }
            }
        }
    }

    private func save() {
        if var updated = client {
            updated.name = name.trimmingCharacters(in: .whitespaces)
            updated.phone = phone.trimmingCharacters(in: .whitespaces)
            updated.note = note
            store.updateClient(updated)
        } else {
            store.addClient(name: name, phone: phone, note: note)
        }
        dismiss()
    }
}
