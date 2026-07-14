import Foundation
import SwiftData

/// 앱 전역 설정. 단일 레코드로만 존재한다 (fetch 시 첫 번째를 사용, 없으면 생성).
///
/// 기획서 7절은 `DateComponents`를 명시하지만, SwiftData 저장/조회 안정성을 위해
/// 시/분을 Int로 저장하고 `DateComponents` 접근자를 계산 프로퍼티로 제공한다.
@Model
final class AppSettings {
    var morningHour: Int
    var morningMinute: Int
    var eveningHour: Int
    var eveningMinute: Int
    var morningEnabled: Bool
    var eveningEnabled: Bool

    init(
        morningHour: Int = 8,
        morningMinute: Int = 0,
        eveningHour: Int = 20,
        eveningMinute: Int = 0,
        morningEnabled: Bool = true,
        eveningEnabled: Bool = true
    ) {
        self.morningHour = morningHour
        self.morningMinute = morningMinute
        self.eveningHour = eveningHour
        self.eveningMinute = eveningMinute
        self.morningEnabled = morningEnabled
        self.eveningEnabled = eveningEnabled
    }

    var morningComponents: DateComponents {
        DateComponents(hour: morningHour, minute: morningMinute)
    }

    var eveningComponents: DateComponents {
        DateComponents(hour: eveningHour, minute: eveningMinute)
    }

    func time(for slot: Slot) -> DateComponents {
        slot == .morning ? morningComponents : eveningComponents
    }

    func isEnabled(_ slot: Slot) -> Bool {
        slot == .morning ? morningEnabled : eveningEnabled
    }

    func setEnabled(_ enabled: Bool, for slot: Slot) {
        if slot == .morning { morningEnabled = enabled } else { eveningEnabled = enabled }
    }

    func setTime(hour: Int, minute: Int, for slot: Slot) {
        if slot == .morning {
            morningHour = hour
            morningMinute = minute
        } else {
            eveningHour = hour
            eveningMinute = minute
        }
    }
}
