import Foundation
import SwiftData

/// 복약 슬롯. v1은 아침/저녁 2개 고정.
enum Slot: String, Codable, CaseIterable, Identifiable, Sendable {
    case morning
    case evening

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: return "아침 약"
        case .evening: return "저녁 약"
        }
    }

    var emoji: String {
        switch self {
        case .morning: return "🌅"
        case .evening: return "🌙"
        }
    }
}

/// 회차별 복약 상태.
enum MedicationStatus: String, Codable, Sendable {
    case pending
    case completed
}

/// 하루의 한 슬롯(아침 또는 저녁)에 대한 복약 기록.
///
/// SwiftData `#Predicate`가 열거형보다 원시 문자열/정수에서 훨씬 안정적으로 동작하므로
/// 저장은 rawValue 문자열로 하고, 사용처에서는 계산 프로퍼티로 열거형을 노출한다.
@Model
final class MedicationRecord {
    /// 해당 기록이 속한 날짜. 항상 그날의 자정(startOfDay)으로 정규화해서 저장한다.
    /// 자정을 넘겨 인증해도 "슬롯의 날짜" 기준으로 기록하기 위함 (기획서 §10).
    var date: Date

    /// `Slot`의 rawValue.
    private(set) var slotRaw: String

    /// `MedicationStatus`의 rawValue.
    private(set) var statusRaw: String

    /// 인증(완료) 시각. 미완료면 nil.
    var completedAt: Date?

    /// 앱 내부 저장소(Documents) 기준 상대 경로. 미완료면 nil.
    var photoPath: String?

    /// 완료 시점의 "예정 시각" 스냅샷. 지연 완료 판정에 사용 (설정을 나중에 바꿔도 판정 불변).
    /// 옵셔널 추가 필드라 기존 데이터와 경량 마이그레이션 호환.
    var scheduledAt: Date?

    var slot: Slot {
        get { Slot(rawValue: slotRaw) ?? .morning }
        set { slotRaw = newValue.rawValue }
    }

    var status: MedicationStatus {
        get { MedicationStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(date: Date, slot: Slot, status: MedicationStatus = .pending, completedAt: Date? = nil, photoPath: String? = nil) {
        self.date = date
        self.slotRaw = slot.rawValue
        self.statusRaw = status.rawValue
        self.completedAt = completedAt
        self.photoPath = photoPath
    }

    /// 완료 처리. 사진 경로와 완료 시각을 함께 기록한다.
    func markCompleted(photoPath: String, at date: Date) {
        self.status = .completed
        self.photoPath = photoPath
        self.completedAt = date
    }

    /// 지연 완료 임계값: 예정 시각 +2시간.
    static let lateThreshold: TimeInterval = 2 * 60 * 60

    /// 지연 완료 여부. 예정 시각 스냅샷이 없으면(과거 데이터) 판정하지 않는다.
    var isLate: Bool {
        guard let completedAt, let scheduledAt else { return false }
        return completedAt.timeIntervalSince(scheduledAt) > Self.lateThreshold
    }
}
