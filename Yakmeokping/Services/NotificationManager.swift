import Foundation
import UserNotifications

/// 로컬 알림 예약/취소 총괄. `NotificationScheduling`의 순수 계산 결과를
/// 실제 `UNUserNotificationCenter` 호출로 옮긴다.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private var calendar: Calendar { Calendar.current }

    private init() {}

    // MARK: - 권한

    /// 알림 권한 요청 (배지·사운드·알림 + timeSensitive 지원).
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - 예약

    /// 특정 슬롯의 오늘치 반복 알림을 예약한다.
    ///
    /// - Parameters:
    ///   - slot: 아침/저녁
    ///   - day: 대상 날짜 (보통 오늘)
    ///   - time: 슬롯 발화 시각(시/분)
    ///   - seqStart: 시작 회차. 최초 예약은 0, foreground 연장 시 누적 회차.
    ///   - now: 현재 시각(테스트 주입 가능)
    func scheduleBatch(for slot: Slot, on day: Date, time: DateComponents, seqStart: Int = 0, now: Date = Date()) {
        guard let baseTime = NotificationScheduling.baseFireDate(for: slot, on: day, settings: time, calendar: calendar) else { return }

        let fireDates = NotificationScheduling.fireDates(baseTime: baseTime, seqStart: seqStart)

        for (offset, fireDate) in fireDates.enumerated() {
            // 이미 지난 시각은 예약하지 않는다 (기획서 §10: 지난 슬롯은 알림 없이 pending).
            guard NotificationScheduling.isFuture(fireDate, now: now) else { continue }

            let seq = seqStart + offset
            let (title, body) = NotificationScheduling.message(forSeq: seq)

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.interruptionLevel = .timeSensitive // 집중 모드에서도 표시
            content.userInfo = ["slot": slot.rawValue, "dayKey": NotificationScheduling.dayKey(day, calendar: calendar)]

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let id = NotificationScheduling.identifier(date: day, slot: slot, seq: seq, calendar: calendar)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    /// 12회 배치 이후를 대비한 희소 후속 알림(+90m/+120m/+180m)을 예약한다.
    /// "1시간 침묵 → 그날 통째로 잊음" 시나리오의 안전망.
    func scheduleFollowUps(for slot: Slot, on day: Date, time: DateComponents, now: Date = Date()) {
        guard let baseTime = NotificationScheduling.baseFireDate(for: slot, on: day, settings: time, calendar: calendar) else { return }

        for (index, offset) in NotificationScheduling.followUpOffsets.enumerated() {
            let fireDate = baseTime.addingTimeInterval(offset)
            guard NotificationScheduling.isFuture(fireDate, now: now) else { continue }

            let (title, body) = NotificationScheduling.followUpMessage(index: index)
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.userInfo = ["slot": slot.rawValue, "dayKey": NotificationScheduling.dayKey(day, calendar: calendar)]

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = NotificationScheduling.followUpIdentifier(date: day, slot: slot, index: index, calendar: calendar)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    /// 두 슬롯의 오늘치 알림을 설정에 맞게 (재)생성한다.
    /// 시각 변경/토글 변경 시 호출한다. 기존 예약은 모두 지우고 다시 예약한다.
    func rescheduleAll(settings: AppSettings, day: Date = Date(), now: Date = Date()) {
        for slot in Slot.allCases {
            cancelSlot(slot, on: day)
            guard settings.isEnabled(slot) else { continue }
            scheduleBatch(for: slot, on: day, time: settings.time(for: slot), seqStart: 0, now: now)
            scheduleFollowUps(for: slot, on: day, time: settings.time(for: slot), now: now)
        }
    }

    // MARK: - 연장 (foreground 진입 시)

    /// 미인증 슬롯의 알림을 다음 배치로 연장한다.
    ///
    /// 슬롯 시각이 이미 지난 상태에서 앱을 열면, 남아 있을 수 있는 미래 예약분을 먼저 정리하고
    /// 현재 시각 기준 다음 회차부터 새 배치를 얹는다(중복 예약 방지). 문구 단계는 계속 누적된다.
    /// 아직 알림센터에 도착해 있는(delivered) 알림은 지우지 않아 사용자가 놓치지 않게 한다.
    func extendIfNeeded(for slot: Slot, on day: Date, time: DateComponents, now: Date = Date()) {
        guard let baseTime = NotificationScheduling.baseFireDate(for: slot, on: day, settings: time, calendar: calendar) else { return }
        // 아직 시작 전이면 최초 배치가 이미 예약돼 있으므로 연장 불필요.
        guard now >= baseTime else { return }

        // 남아 있는 미래 예약분(pending)만 정리 — delivered는 유지.
        let ids = NotificationScheduling.allPossibleIdentifiers(date: day, slot: slot, calendar: calendar)
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let seqStart = NotificationScheduling.nextBatchStartSeq(baseTime: baseTime, now: now)
        scheduleBatch(for: slot, on: day, time: time, seqStart: seqStart, now: now)
        // 후속 알림도 되살린다 (지난 것은 isFuture 가드가 걸러냄).
        scheduleFollowUps(for: slot, on: day, time: time, now: now)
    }

    // MARK: - 취소

    /// 특정 슬롯의 남은 예약 + 이미 도착한 알림을 모두 정리한다 (인증 완료 시 호출).
    func cancelSlot(_ slot: Slot, on day: Date) {
        let ids = NotificationScheduling.allPossibleIdentifiers(date: day, slot: slot, calendar: calendar)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - 디버그

    func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }
}
