import XCTest
@testable import Yakmeokping

/// 알림 예약/취소의 순수 계산 로직 단위 테스트.
/// (기획서 §11: "알림 예약·취소 로직 — 가장 중요, 단위 테스트 포함")
final class NotificationSchedulingTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    // MARK: - dayKey / identifier

    func testDayKeyFormat() {
        let d = date(2026, 7, 14)
        XCTAssertEqual(NotificationScheduling.dayKey(d, calendar: calendar), "20260714")
    }

    func testIdentifierFormat() {
        let d = date(2026, 7, 14)
        let id = NotificationScheduling.identifier(date: d, slot: .morning, seq: 3, calendar: calendar)
        XCTAssertEqual(id, "20260714-morning-3")
    }

    func testIdentifierDiffersBySlot() {
        let d = date(2026, 7, 14)
        let m = NotificationScheduling.identifier(date: d, slot: .morning, seq: 0, calendar: calendar)
        let e = NotificationScheduling.identifier(date: d, slot: .evening, seq: 0, calendar: calendar)
        XCTAssertNotEqual(m, e)
    }

    // MARK: - fireDates

    func testFireDatesCount() {
        let base = date(2026, 7, 14, 8, 0)
        let fires = NotificationScheduling.fireDates(baseTime: base)
        XCTAssertEqual(fires.count, NotificationScheduling.batchCount)
    }

    func testFireDatesInterval() {
        let base = date(2026, 7, 14, 8, 0)
        let fires = NotificationScheduling.fireDates(baseTime: base)
        XCTAssertEqual(fires[0], base)
        XCTAssertEqual(fires[1], base.addingTimeInterval(300))   // +5분
        XCTAssertEqual(fires[11], base.addingTimeInterval(300 * 11)) // T+55분
    }

    func testFireDatesWithSeqStart() {
        let base = date(2026, 7, 14, 8, 0)
        let fires = NotificationScheduling.fireDates(baseTime: base, seqStart: 12)
        // 다음 배치는 T+60분(1시간)부터 시작.
        XCTAssertEqual(fires[0], base.addingTimeInterval(300 * 12))
    }

    // MARK: - baseFireDate

    func testBaseFireDate() {
        let day = date(2026, 7, 14, 15, 30) // 시각 무시하고 슬롯 시각으로 세팅
        let comps = DateComponents(hour: 20, minute: 0)
        let base = NotificationScheduling.baseFireDate(for: .evening, on: day, settings: comps, calendar: calendar)
        XCTAssertEqual(base, date(2026, 7, 14, 20, 0))
    }

    // MARK: - isFuture (지난 슬롯은 예약하지 않음)

    func testIsFuture() {
        let now = date(2026, 7, 14, 8, 10)
        XCTAssertFalse(NotificationScheduling.isFuture(date(2026, 7, 14, 8, 0), now: now))  // 지남
        XCTAssertFalse(NotificationScheduling.isFuture(date(2026, 7, 14, 8, 5), now: now))  // 지남
        XCTAssertTrue(NotificationScheduling.isFuture(date(2026, 7, 14, 8, 15), now: now))  // 미래
    }

    // MARK: - message 단계 (순차, 랜덤 아님)

    func testMessageProgression() {
        XCTAssertTrue(NotificationScheduling.message(forSeq: 0).title.contains("약 먹을 시간"))
        XCTAssertTrue(NotificationScheduling.message(forSeq: 1).title.contains("아직 안 먹었지"))
        XCTAssertTrue(NotificationScheduling.message(forSeq: 2).title.contains("약속했잖아"))
        // 4회차 이후: 경과 분 안내
        XCTAssertTrue(NotificationScheduling.message(forSeq: 3).title.contains("15분"))
        XCTAssertTrue(NotificationScheduling.message(forSeq: 6).title.contains("30분"))
    }

    // MARK: - nextBatchStartSeq (foreground 연장)

    func testNextBatchStartSeqBeforeStart() {
        let base = date(2026, 7, 14, 8, 0)
        let now = date(2026, 7, 14, 7, 30) // 아직 시작 전
        XCTAssertEqual(NotificationScheduling.nextBatchStartSeq(baseTime: base, now: now), 0)
    }

    func testNextBatchStartSeqAfterSomeIntervals() {
        let base = date(2026, 7, 14, 8, 0)
        // 32분 경과 → 6번째 간격(0..6=6개 지남, floor(32/5)=6) → 다음은 7
        let now = date(2026, 7, 14, 8, 32)
        XCTAssertEqual(NotificationScheduling.nextBatchStartSeq(baseTime: base, now: now), 7)
    }

    func testNextBatchStartSeqExactBoundary() {
        let base = date(2026, 7, 14, 8, 0)
        let now = date(2026, 7, 14, 8, 25) // 정확히 25분 = seq5 발화시각, floor=5 → 다음 6
        XCTAssertEqual(NotificationScheduling.nextBatchStartSeq(baseTime: base, now: now), 6)
    }

    // MARK: - needsExtension

    func testNeedsExtensionFalseWhenBatchStillFuture() {
        let base = date(2026, 7, 14, 8, 0)
        // 첫 배치(seq0..11)의 마지막 발화는 T+55분(08:55).
        let now = date(2026, 7, 14, 8, 30)
        XCTAssertFalse(NotificationScheduling.needsExtension(baseTime: base, lastScheduledSeqStart: 0, now: now))
    }

    func testNeedsExtensionTrueWhenBatchPassed() {
        let base = date(2026, 7, 14, 8, 0)
        let now = date(2026, 7, 14, 9, 0) // 08:55 이후
        XCTAssertTrue(NotificationScheduling.needsExtension(baseTime: base, lastScheduledSeqStart: 0, now: now))
    }

    // MARK: - allPossibleIdentifiers (슬롯 일괄 취소용)

    func testAllPossibleIdentifiersCoversBatchAndFollowUps() {
        let d = date(2026, 7, 14)
        let ids = NotificationScheduling.allPossibleIdentifiers(date: d, slot: .morning, calendar: calendar, maxSeq: 12)
        XCTAssertTrue(ids.contains("20260714-morning-0"))
        XCTAssertTrue(ids.contains("20260714-morning-11"))
        // 후속 알림 식별자도 포함되어 인증 시 함께 취소된다.
        XCTAssertTrue(ids.contains("20260714-morning-fu-0"))
        XCTAssertTrue(ids.contains("20260714-morning-fu-2"))
        XCTAssertEqual(ids.count, 13 + NotificationScheduling.followUpOffsets.count)
    }

    // MARK: - 후속(follow-up) 알림

    func testFollowUpIdentifierFormat() {
        let d = date(2026, 7, 14)
        let id = NotificationScheduling.followUpIdentifier(date: d, slot: .evening, index: 1, calendar: calendar)
        XCTAssertEqual(id, "20260714-evening-fu-1")
    }

    func testFollowUpOffsetsAreSparseAndOrdered() {
        let offsets = NotificationScheduling.followUpOffsets
        XCTAssertEqual(offsets.count, 3)
        // 12회 배치(T+55분) 이후에 위치해야 한다.
        XCTAssertTrue(offsets.allSatisfy { $0 > 55 * 60 })
        XCTAssertEqual(offsets, offsets.sorted())
    }

    func testFollowUpMessagesAreDistinct() {
        let titles = (0..<3).map { NotificationScheduling.followUpMessage(index: $0).title }
        XCTAssertEqual(Set(titles).count, 3)
    }

    // MARK: - dayKey 파싱 (알림 탭 → 날짜 복원)

    func testParseDayKeyRoundTrip() {
        let d = date(2026, 7, 14)
        let key = NotificationScheduling.dayKey(d, calendar: calendar)
        let parsed = NotificationScheduling.parseDayKey(key, calendar: calendar)
        XCTAssertEqual(parsed, calendar.startOfDay(for: d))
    }

    func testParseDayKeyRejectsInvalid() {
        XCTAssertNil(NotificationScheduling.parseDayKey("2026714", calendar: calendar))   // 7자리
        XCTAssertNil(NotificationScheduling.parseDayKey("abcdefgh", calendar: calendar))  // 숫자 아님
    }

    // MARK: - 자정 넘김 귀속 (기획 §10)

    func testLateNightAttributedDayBeforeCutoff() {
        // 새벽 00:30 → 어제
        let now = date(2026, 7, 15, 0, 30)
        let attributed = NotificationScheduling.lateNightAttributedDay(now: now, calendar: calendar)
        XCTAssertEqual(attributed, date(2026, 7, 14))
    }

    func testLateNightAttributedDayJustBeforeCutoff() {
        let now = date(2026, 7, 15, 2, 59)
        XCTAssertEqual(NotificationScheduling.lateNightAttributedDay(now: now, calendar: calendar), date(2026, 7, 14))
    }

    func testLateNightAttributedDayAtCutoff() {
        // 03:00 정각부터는 귀속 없음
        let now = date(2026, 7, 15, 3, 0)
        XCTAssertNil(NotificationScheduling.lateNightAttributedDay(now: now, calendar: calendar))
    }

    func testLateNightAttributedDayDaytime() {
        let now = date(2026, 7, 15, 14, 0)
        XCTAssertNil(NotificationScheduling.lateNightAttributedDay(now: now, calendar: calendar))
    }

    // MARK: - 지연 완료 판정 (P1)

    func testIsLateFalseWithinThreshold() {
        let record = MedicationRecord(date: date(2026, 7, 14), slot: .morning)
        record.markCompleted(photoPath: "photos/x.jpg", at: date(2026, 7, 14, 9, 59))
        record.scheduledAt = date(2026, 7, 14, 8, 0)
        XCTAssertFalse(record.isLate) // +1시간 59분 → 정시 완료
    }

    func testIsLateTrueBeyondThreshold() {
        let record = MedicationRecord(date: date(2026, 7, 14), slot: .morning)
        record.markCompleted(photoPath: "photos/x.jpg", at: date(2026, 7, 14, 10, 1))
        record.scheduledAt = date(2026, 7, 14, 8, 0)
        XCTAssertTrue(record.isLate) // +2시간 1분 → 지연 완료
    }

    func testIsLateFalseWithoutSnapshot() {
        // 과거 데이터(스냅샷 없음)는 지연으로 판정하지 않는다.
        let record = MedicationRecord(date: date(2026, 7, 14), slot: .morning)
        record.markCompleted(photoPath: "photos/x.jpg", at: date(2026, 7, 14, 23, 0))
        XCTAssertFalse(record.isLate)
    }
}
