import SwiftUI

/// 월간 캘린더 히스토리. 날짜마다 아침/저녁 완료 여부를 두 개의 하트로 표시한다.
/// 채워진 핑크 하트 = 완료, 빈 하트 = 미완료 (사후 수정 불가, 정직한 기록).
struct CalendarView: View {
    @Environment(MedicationStore.self) private var store

    @State private var displayedMonth: Date = Date()
    @State private var selectedDay: Date?
    @State private var completionRate: Int = 0

    private var calendar: Calendar { store.calendar }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    monthHeader
                    summaryCard
                    weekdayHeader
                    grid
                }
                .padding(20)
            }
        }
        .onAppear(perform: refresh)
        .sheet(item: $selectedDay) { day in
            DayDetailView(day: day)
                .environment(store)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - 월 이동 헤더

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.mainPink)
            }
            .buttonStyle(.bouncy)

            Spacer()
            Text(monthTitle)
                .font(Theme.rounded(22, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()

            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canGoForward ? Theme.mainPink : Theme.mainPink.opacity(0.3))
            }
            .buttonStyle(.bouncy)
            .disabled(!canGoForward)
        }
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("이번 달 완료율")
                    .font(Theme.rounded(14))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(completionRate)%")
                    .font(Theme.rounded(34, weight: .bold))
                    .foregroundStyle(Theme.mainPink)
            }
            Spacer()
            Text(completionRate >= 80 ? "🏆" : completionRate >= 50 ? "💪" : "🌱")
                .font(.system(size: 44))
        }
        .cardStyle()
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(["일","월","화","수","목","금","토"], id: \.self) { day in
                Text(day)
                    .font(Theme.rounded(13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let days = monthGridDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 10) {
            ForEach(days.indices, id: \.self) { i in
                if let day = days[i] {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 60)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isFuture = calendar.startOfDay(for: day) > calendar.startOfDay(for: Date())
        let morning = store.record(for: .morning, on: day)?.status == .completed
        let evening = store.record(for: .evening, on: day)?.status == .completed
        let isToday = calendar.isDateInToday(day)

        return Button {
            guard !isFuture else { return }
            Haptics.tap()
            selectedDay = day
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(Theme.rounded(14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Theme.mainPink : Theme.textPrimary)
                HStack(spacing: 3) {
                    heartIcon(filled: morning)
                    heartIcon(filled: evening)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isToday ? Theme.lightPink.opacity(0.7) : Color.white)
            )
            .opacity(isFuture ? 0.4 : 1)
        }
        .buttonStyle(.bouncy)
        .disabled(isFuture)
    }

    private func heartIcon(filled: Bool) -> some View {
        Image(systemName: filled ? "heart.fill" : "heart")
            .font(.system(size: 12))
            .foregroundStyle(filled ? Theme.mainPink : Theme.textSecondary.opacity(0.4))
    }

    // MARK: - 로직

    private func refresh() {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        completionRate = store.monthlyCompletionRate(year: comps.year ?? 0, month: comps.month ?? 0)
    }

    private func changeMonth(_ delta: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        if delta > 0 && !canGoForward { return }
        displayedMonth = newMonth
        Haptics.tap()
        refresh()
    }

    private var canGoForward: Bool {
        let now = Date()
        let curComps = calendar.dateComponents([.year, .month], from: displayedMonth)
        let nowComps = calendar.dateComponents([.year, .month], from: now)
        return (curComps.year ?? 0, curComps.month ?? 0) < (nowComps.year ?? 0, nowComps.month ?? 0)
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f.string(from: displayedMonth)
    }

    /// 그 달 1일의 요일에 맞춰 앞쪽을 nil로 채운 42칸(또는 필요 칸) 배열.
    private func monthGridDays() -> [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart) // 1=일
        var cells: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(date)
            }
        }
        return cells
    }
}

extension Date: Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}
