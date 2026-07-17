import WidgetKit
import SwiftUI

// MARK: - 앱 ↔ 위젯 데이터 계약
// 앱(WidgetBridge)이 App Group UserDefaults에 쓰는 JSON과 필드가 일치해야 한다.

struct TodaySnapshot: Codable {
    var dayKey: String          // yyyyMMdd — 오늘 데이터인지 검증용
    var morningEnabled: Bool
    var eveningEnabled: Bool
    var morningDone: Bool
    var eveningDone: Bool
    var morningTime: String     // "08:00"
    var eveningTime: String     // "20:00"
    var streak: Int

    static let empty = TodaySnapshot(dayKey: "", morningEnabled: true, eveningEnabled: true,
                                     morningDone: false, eveningDone: false,
                                     morningTime: "08:00", eveningTime: "20:00", streak: 0)
}

enum WidgetShared {
    static let suiteName = "group.com.yakmeokping.app"
    static let snapshotKey = "todaySnapshot"

    static func load() -> TodaySnapshot {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(TodaySnapshot.self, from: data) else {
            return .empty
        }
        // 어제 데이터가 남아있으면 "오늘은 아직 미완료"로 표시.
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        if snapshot.dayKey != f.string(from: Date()) {
            var stale = snapshot
            stale.morningDone = false
            stale.eveningDone = false
            return stale
        }
        return snapshot
    }
}

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaySnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), snapshot: WidgetShared.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: Date(), snapshot: WidgetShared.load())
        // 앱이 상태 변화 시 reloadAllTimelines를 호출하지만,
        // 자정·슬롯 시각 경과 대비로 30분마다 자체 갱신도 건다.
        let next = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - 위젯 정의

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘의 약")
        .description("아침·저녁 복약 인증 상태를 한눈에 봐요 💗")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - 뷰

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var snap: TodaySnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            small
        }
    }

    // 잠금화면 원형: 두 슬롯 하트를 나란히.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            HStack(spacing: 3) {
                Image(systemName: snap.morningDone ? "heart.fill" : "heart")
                Image(systemName: snap.eveningDone ? "heart.fill" : "heart")
            }
            .font(.system(size: 15, weight: .bold))
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // 잠금화면 직사각형: 슬롯별 상태 + 시간.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("약먹핑 💊")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            slotLine(emoji: "🌅", done: snap.morningDone, enabled: snap.morningEnabled, time: snap.morningTime)
            slotLine(emoji: "🌙", done: snap.eveningDone, enabled: snap.eveningEnabled, time: snap.eveningTime)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }

    private func slotLine(emoji: String, done: Bool, enabled: Bool, time: String) -> some View {
        HStack(spacing: 4) {
            Text(emoji).font(.system(size: 11))
            Image(systemName: enabled ? (done ? "heart.fill" : "heart") : "moon.zzz")
                .font(.system(size: 11, weight: .bold))
            Text(enabled ? (done ? "완료" : time) : "쉬는 날")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
    }

    // 홈 화면 small: 핑크 카드.
    private var small: some View {
        let pink = Color(red: 1.0, green: 0.56, blue: 0.78)
        let purple = Color(red: 0.78, green: 0.60, blue: 0.96)
        let ink = Color(red: 0.35, green: 0.29, blue: 0.33)

        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("오늘의 약")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                Spacer()
                Text("💊")
            }
            Spacer(minLength: 0)
            bigSlotRow(emoji: "🌅", label: "아침", done: snap.morningDone, enabled: snap.morningEnabled,
                       time: snap.morningTime, pink: pink, ink: ink)
            bigSlotRow(emoji: "🌙", label: "저녁", done: snap.eveningDone, enabled: snap.eveningEnabled,
                       time: snap.eveningTime, pink: pink, ink: ink)
            Spacer(minLength: 0)
            if snap.streak > 0 {
                Text("🔥 연속 \(snap.streak)일째!")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(purple)
            } else {
                Text("오늘부터 시작! 💕")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(purple)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 1.0, green: 0.97, blue: 0.98),
                                    Color(red: 1.0, green: 0.88, blue: 0.94)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    private func bigSlotRow(emoji: String, label: String, done: Bool, enabled: Bool,
                            time: String, pink: Color, ink: Color) -> some View {
        HStack(spacing: 6) {
            Text(emoji).font(.system(size: 13))
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
            Spacer()
            if !enabled {
                Text("쉬는 날")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(ink.opacity(0.5))
            } else if done {
                Image(systemName: "heart.fill").foregroundStyle(pink).font(.system(size: 13, weight: .bold))
            } else {
                Text(time)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.65))
                Image(systemName: "heart").foregroundStyle(pink.opacity(0.6)).font(.system(size: 13, weight: .bold))
            }
        }
    }
}
