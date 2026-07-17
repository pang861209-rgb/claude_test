import Foundation
import WidgetKit

/// 앱 → 위젯으로 오늘의 복약 상태를 전달한다.
/// App Group UserDefaults에 JSON 스냅샷을 쓰고 위젯 타임라인을 갱신한다.
/// (위젯 쪽 `TodaySnapshot`과 필드가 계약으로 일치해야 함)
enum WidgetBridge {
    static let suiteName = "group.com.yakmeokping.app"
    static let snapshotKey = "todaySnapshot"

    private struct Snapshot: Codable {
        var dayKey: String
        var morningEnabled: Bool
        var eveningEnabled: Bool
        var morningDone: Bool
        var eveningDone: Bool
        var morningTime: String
        var eveningTime: String
        var streak: Int
    }

    /// 현재 상태를 위젯에 게시한다. 상태가 바뀌는 지점(홈 갱신·인증 완료·설정 변경)에서 호출.
    static func publish(records: [Slot: MedicationRecord],
                        streak: Int,
                        settings: AppSettings,
                        calendar: Calendar = .current,
                        now: Date = Date()) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        let snapshot = Snapshot(
            dayKey: NotificationScheduling.dayKey(now, calendar: calendar),
            morningEnabled: settings.morningEnabled,
            eveningEnabled: settings.eveningEnabled,
            morningDone: records[.morning]?.status == .completed,
            eveningDone: records[.evening]?.status == .completed,
            morningTime: String(format: "%02d:%02d", settings.morningHour, settings.morningMinute),
            eveningTime: String(format: "%02d:%02d", settings.eveningHour, settings.eveningMinute),
            streak: streak
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
