import Foundation
import SwiftData
import UIKit

/// 복약 기록·설정에 대한 읽기/쓰기와 파생 계산(streak, 완료율)을 담당하는 스토어.
/// SwiftData `ModelContext`를 감싸 뷰가 액션 단위로 호출한다.
@MainActor
@Observable
final class MedicationStore {
    private let context: ModelContext
    var calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// 명시적으로 컨텍스트를 저장한다.
    func save() {
        try? context.save()
    }

    // MARK: - 설정

    /// 앱 설정을 가져오거나, 없으면 기본값으로 생성한다 (단일 레코드 보장).
    func loadOrCreateSettings() -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        try? context.save()
        return settings
    }

    // MARK: - 오늘 기록 보장

    /// 대상 날짜의 두 슬롯 기록이 없으면 pending으로 생성한다.
    @discardableResult
    func ensureRecords(for day: Date = Date()) -> [Slot: MedicationRecord] {
        let start = calendar.startOfDay(for: day)
        var result: [Slot: MedicationRecord] = [:]
        for slot in Slot.allCases {
            if let existing = record(for: slot, on: start) {
                result[slot] = existing
            } else {
                let record = MedicationRecord(date: start, slot: slot)
                context.insert(record)
                result[slot] = record
            }
        }
        try? context.save()
        return result
    }

    /// 특정 날짜·슬롯의 기록을 조회한다.
    func record(for slot: Slot, on day: Date) -> MedicationRecord? {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let slotRaw = slot.rawValue
        let descriptor = FetchDescriptor<MedicationRecord>(
            predicate: #Predicate { record in
                record.date >= start && record.date < end && record.slotRaw == slotRaw
            }
        )
        return try? context.fetch(descriptor).first
    }

    /// 지정 기간의 모든 기록.
    func records(from startDate: Date, to endDate: Date) -> [MedicationRecord] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let descriptor = FetchDescriptor<MedicationRecord>(
            predicate: #Predicate { record in
                record.date >= start && record.date <= end
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 완료 처리

    /// 사진 인증으로 슬롯을 완료 처리한다.
    /// 1) 사진 저장 2) 기록 완료 저장 3) 남은 알림 취소.
    /// - Returns: 성공 시 완료된 record, 실패(사진 저장 실패) 시 nil.
    @discardableResult
    func complete(slot: Slot, on day: Date = Date(), image: UIImage, at now: Date = Date()) -> MedicationRecord? {
        guard let path = PhotoStorage.save(image) else { return nil }

        let start = calendar.startOfDay(for: day)
        let record = record(for: slot, on: start) ?? {
            let r = MedicationRecord(date: start, slot: slot)
            context.insert(r)
            return r
        }()

        record.markCompleted(photoPath: path, at: now)
        try? context.save()

        NotificationManager.shared.cancelSlot(slot, on: start)
        return record
    }

    // MARK: - Streak (연속 성공 일수)

    /// 오늘(또는 기준일)로부터 거슬러 올라가며, 하루 2회를 모두 완료한 날의 연속 수.
    /// 오늘이 아직 미완료여도 어제까지의 연속은 유지한다.
    func currentStreak(asOf day: Date = Date()) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: day)

        while true {
            let complete = isFullyCompleted(on: cursor)
            if complete {
                streak += 1
            } else {
                // 오늘이 아직 미완료인 것은 streak를 끊지 않는다 (어제까지 유지).
                if cursor == today {
                    // 통과
                } else {
                    break
                }
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
            // 무한 방지: 최대 3650일(약 10년)까지만 조회.
            if streak > 3650 { break }
        }
        return streak
    }

    /// 그날 두 슬롯이 모두 완료 상태인가.
    func isFullyCompleted(on day: Date) -> Bool {
        let morning = record(for: .morning, on: day)
        let evening = record(for: .evening, on: day)
        return morning?.status == .completed && evening?.status == .completed
    }

    // MARK: - 월간 요약

    /// 해당 월의 완료율(%). 분모는 (경과한 날 수 × 2), 분자는 완료 회차 수.
    /// 미래 날짜는 분모에서 제외한다.
    func monthlyCompletionRate(year: Int, month: Int, asOf now: Date = Date()) -> Int {
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else { return 0 }

        let today = calendar.startOfDay(for: now)
        var completed = 0
        var total = 0

        for day in range {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
            let start = calendar.startOfDay(for: date)
            if start > today { break } // 미래 제외

            for slot in Slot.allCases {
                total += 1
                if record(for: slot, on: start)?.status == .completed {
                    completed += 1
                }
            }
        }
        guard total > 0 else { return 0 }
        return Int((Double(completed) / Double(total) * 100).rounded())
    }
}
