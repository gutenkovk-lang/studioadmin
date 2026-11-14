import Foundation
import AVFoundation
import AudioToolbox
import UserNotifications

/// Сигнал окончания аренды:
/// — если приложение открыто, мелодия играет по кругу и телефон вибрирует, пока администратор не ответит;
/// — если приложение свёрнуто или экран заблокирован, приходит уведомление с той же мелодией.
@MainActor
final class AlarmManager {
    static let shared = AlarmManager()

    private var player: AVAudioPlayer?
    private var vibrationTimer: Timer?

    // MARK: Уведомления

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func schedule(for rental: Rental, settings: AppSettings) {
        cancel(for: rental.id)
        guard rental.isActive else { return }
        let center = UNUserNotificationCenter.current()

        let untilEnd = rental.plannedEnd.timeIntervalSinceNow
        if untilEnd > 1 {
            let content = UNMutableNotificationContent()
            content.title = "Время аренды вышло"
            content.body = "\(rental.hallName) · \(rental.clientName)"
            content.sound = UNNotificationSound(named: UNNotificationSoundName(settings.melody.fileName))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: untilEnd, repeats: false)
            center.add(UNNotificationRequest(identifier: endID(rental.id), content: content, trigger: trigger))
        }

        if settings.warnMinutes > 0 {
            let untilWarn = untilEnd - Double(settings.warnMinutes) * 60
            if untilWarn > 1 {
                let content = UNMutableNotificationContent()
                content.title = "Осталось \(settings.warnMinutes) мин"
                content.body = "\(rental.hallName) · \(rental.clientName)"
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: untilWarn, repeats: false)
                center.add(UNNotificationRequest(identifier: warnID(rental.id), content: content, trigger: trigger))
            }
        }
    }

    func cancel(for id: UUID) {
        let ids = [endID(id), warnID(id)]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func endID(_ id: UUID) -> String { id.uuidString + "-end" }
    private func warnID(_ id: UUID) -> String { id.uuidString + "-warn" }

    // MARK: Звук и вибрация в открытом приложении

    func startRinging(melody: Melody, vibration: Bool) {
        stopRinging()
        play(melody, loops: -1)
        if vibration {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }

    func stopRinging() {
        player?.stop()
        player = nil
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }

    /// Один раз проиграть мелодию — для выбора в настройках.
    func preview(_ melody: Melody, vibration: Bool) {
        stopRinging()
        play(melody, loops: 0)
        if vibration {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    private func play(_ melody: Melody, loops: Int) {
        // .playback — чтобы сигнал был слышен даже в беззвучном режиме.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)

        let url = Bundle.main.url(forResource: melody.rawValue, withExtension: "wav")
            ?? Bundle.main.url(forResource: melody.rawValue, withExtension: "wav", subdirectory: "Sounds")
        guard let url else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = loops
        player?.prepareToPlay()
        player?.play()
    }
}
