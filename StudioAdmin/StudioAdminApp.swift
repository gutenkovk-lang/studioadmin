import SwiftUI

@main
struct StudioAdminApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ZStack {
            TabView {
                HallsView()
                    .tabItem { Label("Залы", systemImage: "square.grid.2x2") }
                ClientsView()
                    .tabItem { Label("Клиенты", systemImage: "person.2") }
                EarningsView()
                    .tabItem { Label("Заработок", systemImage: "chart.bar") }
                SettingsView()
                    .tabItem { Label("Настройки", systemImage: "gearshape") }
            }

            if let id = store.ringingID, let rental = store.rental(id) {
                AlarmOverlay(rental: rental)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.ringingID)
        .onAppear {
            AlarmManager.shared.requestPermission()
        }
    }
}

/// Экран «Время вышло» поверх всего приложения.
struct AlarmOverlay: View {
    @EnvironmentObject var store: Store
    let rental: Rental

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "bell.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse)

                Text("Время вышло")
                    .font(.largeTitle.bold())

                VStack(spacing: 4) {
                    Text(rental.hallName)
                        .font(.title3.weight(.semibold))
                    Text(rental.clientName)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        store.finish(rental.id)
                    } label: {
                        Text("Завершить аренду")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    HStack(spacing: 10) {
                        ForEach([15, 30], id: \.self) { minutes in
                            Button {
                                store.extend(rental.id, minutes: minutes)
                            } label: {
                                Text("+\(minutes) мин")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }

                    Button("Выключить сигнал") {
                        store.silence()
                    }
                    .padding(.top, 6)
                }
            }
            .padding(24)
        }
    }
}
