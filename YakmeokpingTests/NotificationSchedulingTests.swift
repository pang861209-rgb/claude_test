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

    func testAllPossibleIdentifiersCoversBatch() {
        let d = date(2026, 7, 14)
        let ids = NotificationScheduling.allPossibleIdentifiers(date: d, slot: .morning, calendar: calendar, maxSeq: 12)
        XCTAssertTrue(ids.contains("20260714-morning-0"))
        XCTAssertTrue(ids.contains("20260714-morning-11"))
        XCTAssertEqual(ids.count, 13) // 0...12
    }
}
