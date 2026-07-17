import Foundation

/// 알림 예약/취소를 위한 **순수 함수** 모음.
///
/// `UNUserNotificationCenter`에 의존하지 않으므로 단위 테스트가 가능하다.
/// 실제 예약/취소는 `NotificationManager`가 이 계산 결과를 사용해 수행한다.
enum NotificationScheduling {

    /// 반복 알림 간격 (5분).
    static let interval: TimeInterval = 5 * 60

    /// 한 번에 예약하는 반복 알림 개수 (12개 = 1시간치).
    /// iOS 로컬 알림 예약 상한(64개)을 넘지 않도록 "열 때마다 연장" 전략을 쓴다.
    static let batchCount: Int = 12

    /// 12회 이후의 희소 후속 알림 오프셋 (기준 시각 T로부터).
    /// "1시간 침묵 → 그날 통째로 잊음"을 막는 안전망 (UX 리뷰 §05).
    static let followUpOffsets: [TimeInterval] = [90 * 60, 120 * 60, 180 * 60]

    /// yyyyMMdd 형태의 날짜 키.
    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// dayKey("20260714")를 해당 날짜의 자정 Date로 되돌린다.
    static func parseDayKey(_ key: String, calendar: Calendar) -> Date? {
        guard key.count == 8,
              let y = Int(key.prefix(4)),
              let m = Int(key.dropFirst(4).prefix(2)),
              let d = Int(key.dropFirst(6)) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: d))
    }

    /// 단일 알림 식별자. 규칙: `{yyyyMMdd}-{slot}-{seq}`.
    static func identifier(date: Date, slot: Slot, seq: Int, calendar: Calendar) -> String {
        "\(dayKey(date, calendar: calendar))-\(slot.rawValue)-\(seq)"
    }

    /// 후속(follow-up) 알림 식별자. 5분 배치와 네임스페이스를 분리해 충돌을 막는다.
    /// 규칙: `{yyyyMMdd}-{slot}-fu-{index}`.
    static func followUpIdentifier(date: Date, slot: Slot, index: Int, calendar: Calendar) -> String {
        "\(dayKey(date, calendar: calendar))-\(slot.rawValue)-fu-\(index)"
    }

    /// 하루의 한 슬롯이 만들 수 있는 **모든** 식별자 (5분 배치 + 후속 알림).
    /// seq 0 ~ maxSeq 까지 넉넉히 생성해 슬롯 단위 일괄 취소에 사용한다.
    /// (한 슬롯당 하루 최대 예약 회차를 넉넉히 커버: 하루 12회 배치를 여러 번 연장해도 안전)
    static func allPossibleIdentifiers(date: Date, slot: Slot, calendar: Calendar, maxSeq: Int = 288) -> [String] {
        var ids = (0...maxSeq).map { identifier(date: date, slot: slot, seq: $0, calendar: calendar) }
        ids += followUpOffsets.indices.map { followUpIdentifier(date: date, slot: slot, index: $0, calendar: calendar) }
        return ids
    }

    /// 기준 시각(baseTime)으로부터 seqStart 회차부터 batchCount 개의 발화 시각.
    /// 예: baseTime=08:00, seqStart=0 → [08:00, 08:05, ..., 08:55]
    static func fireDates(baseTime: Date, seqStart: Int = 0, count: Int = batchCount) -> [Date] {
        (0..<count).map { baseTime.addingTimeInterval(interval * Double(seqStart + $0)) }
    }

    /// 특정 슬롯의 오늘 기준 시각(T)을 계산한다.
    /// 설정된 시/분을 오늘 날짜에 적용한 Date.
    static func baseFireDate(for slot: Slot, on day: Date, settings components: DateComponents, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: components.hour ?? 0,
                      minute: components.minute ?? 0,
                      second: 0,
                      of: day)
    }

    /// 알림이 지금 시점에서 예약 대상인지 (미래인지) 판단.
    static func isFuture(_ fireDate: Date, now: Date) -> Bool {
        fireDate > now
    }

    /// 회차(seq, 0-based)와 경과 분에 따른 단계별 알림 문구 (랜덤 아님·순차).
    static func message(forSeq seq: Int) -> (title: String, body: String) {
        switch seq {
        case 0:
            return ("약 먹을 시간이야! 💊", "인증샷 찍으러 가자 📸")
        case 1:
            return ("아직 안 먹었지? ⏰", "5분 지났어! 지금 인증하기 💕")
        case 2:
            return ("약속했잖아~ 🤙", "얼른 먹고 인증하기! 🌸")
        default:
            let minutes = seq * 5
            return ("\(minutes)분째 기다리는 중... 🥺", "딱 한 장이면 끝! 📸✨")
        }
    }

    /// 후속(follow-up) 알림 문구. 부담 없는 톤 유지.
    static func followUpMessage(index: Int) -> (title: String, body: String) {
        switch index {
        case 0:
            return ("\(Branding.characterName)가 아직 기다리고 있어요 🥺", "바빴지? 지금이라도 딱 한 장! 📸")
        case 1:
            return ("오늘의 약, 잊지 않았죠? 💊", "인증하면 \(Branding.characterName)가 폴짝 뛰어요 💕")
        default:
            return ("마지막으로 살짝 알려드려요 🌙", "늦어도 괜찮아요, 지금 인증해요! 💗")
        }
    }

    /// 자정을 넘긴 새벽 시간대라면 "어제" 날짜를 반환한다 (저녁 약 귀속용, 기획 §10).
    /// cutoffHour(기본 03시) 이전이면 어제, 그 외엔 nil.
    static func lateNightAttributedDay(now: Date, cutoffHour: Int = 3, calendar: Calendar) -> Date? {
        let hour = calendar.component(.hour, from: now)
        guard hour < cutoffHour else { return nil }
        return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
    }

    /// foreground 진입 시 "다음 배치"의 시작 회차를 계산한다.
    ///
    /// baseTime 이후 지금(now)까지 몇 개의 5분 간격이 지났는지를 바탕으로,
    /// 아직 예약되지 않은 다음 회차부터 이어서 예약하기 위한 seqStart를 반환한다.
    /// 문구 단계가 계속 이어지도록 seq는 누적된다.
    static func nextBatchStartSeq(baseTime: Date, now: Date) -> Int {
        guard now > baseTime else { return 0 }
        let elapsed = now.timeIntervalSince(baseTime)
        // 이미 지난 마지막 간격의 다음 회차부터.
        return Int(floor(elapsed / interval)) + 1
    }

    /// 마지막으로 예약했던 배치가 이미 다 지났는지(연장이 필요한지) 판단.
    /// lastScheduledSeqStart 배치(= seqStart ... seqStart+count-1)의 마지막 발화 시각이
    /// now 이전이면 true.
    static func needsExtension(baseTime: Date, lastScheduledSeqStart: Int, now: Date, count: Int = batchCount) -> Bool {
        let lastSeq = lastScheduledSeqStart + count - 1
        let lastFire = baseTime.addingTimeInterval(interval * Double(lastSeq))
        return now >= lastFire
    }
}
