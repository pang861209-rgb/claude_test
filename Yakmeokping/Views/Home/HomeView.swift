import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(MedicationStore.self) private var store
    @Environment(PermissionManager.self) private var permissions
    @Environment(AppRouter.self) private var router
    let settings: AppSettings

    @State private var records: [Slot: MedicationRecord] = [:]
    @State private var streak: Int = 0
    @State private var verifyingSlot: Slot?
    @State private var heartTrigger: Int = 0
    @State private var now: Date = Date()

    // 1분마다 상태 갱신 (대기 → 지금 먹을 시간 전환 반영).
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header

                    if !permissions.notificationGranted {
                        PermissionBanner()
                            .popIn()
                    }

                    MascotView(mood: mascotMood, size: 150)
                        .frame(height: 220)
                        .popIn(delay: 0.05)

                    StreakView(streak: streak)
                        .popIn(delay: 0.1)

                    ForEach(Array(Slot.allCases.enumerated()), id: \.element) { index, slot in
                        SlotCardView(
                            slot: slot,
                            state: state(for: slot),
                            scheduledTime: settings.time(for: slot),
                            onTapVerify: { startVerify(slot) }
                        )
                        .attentionWiggle(active: state(for: slot) == .dueNow)
                        .popIn(delay: 0.15 + Double(index) * 0.08)
                    }
                }
                .padding(20)
            }

            HeartBurstView(trigger: $heartTrigger)
        }
        .onAppear {
            refresh()
            handlePendingRoute()
        }
        .onReceive(ticker) { date in
            now = date
            refresh()
        }
        .onChange(of: router.pendingVerifySlot) { _, _ in handlePendingRoute() }
        .fullScreenCover(item: $verifyingSlot) { slot in
            VerificationFlow(slot: slot, day: Date(), store: store) {
                verifyingSlot = nil
                Haptics.celebrate()
                heartTrigger += 1
                refresh()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text(todayString)
                .font(Theme.rounded(15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text("오늘도 약 잘 챙겨요 💗")
                .font(Theme.rounded(24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 상태 계산

    private func state(for slot: Slot) -> SlotCardView.SlotState {
        guard settings.isEnabled(slot) else { return .disabled }
        if let record = records[slot], record.status == .completed, let at = record.completedAt {
            return .completed(at: at, photoPath: record.photoPath)
        }
        // pending: 시간 도래 여부
        if let base = NotificationScheduling.baseFireDate(for: slot, on: now, settings: settings.time(for: slot), calendar: store.calendar),
           now >= base {
            return .dueNow
        }
        return .waiting
    }

    private var mascotMood: MascotView.Mood {
        let states = Slot.allCases.map { state(for: $0) }
        if states.contains(.dueNow) { return .waiting }
        let activeSlots = Slot.allCases.filter { settings.isEnabled($0) }
        let allDone = !activeSlots.isEmpty && activeSlots.allSatisfy {
            if case .completed = state(for: $0) { return true }
            return false
        }
        return allDone ? .happy : .idle
    }

    private func startVerify(_ slot: Slot) {
        Haptics.pop()
        verifyingSlot = slot
    }

    /// 알림 탭으로 전달된 슬롯이 있으면 카메라 화면을 연다.
    private func handlePendingRoute() {
        guard let slot = router.pendingVerifySlot else { return }
        router.pendingVerifySlot = nil
        // 이미 완료된 슬롯이면 무시.
        if let record = store.record(for: slot, on: Date()), record.status == .completed { return }
        verifyingSlot = slot
    }

    private func refresh() {
        records = store.ensureRecords(for: now)
        streak = store.currentStreak(asOf: now)
    }

    private var todayString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: now)
    }
}

/// 알림 권한이 꺼져 있을 때 상단에 상시 노출되는 경고 배너.
struct PermissionBanner: View {
    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(Theme.pointPurple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("알림이 꺼져 있어요")
                        .font(Theme.rounded(15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("설정에서 알림을 켜면 약 시간을 알려줄게요 🔔")
                        .font(Theme.rounded(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: 0xFFF3C4).opacity(0.6))
            )
        }
        .buttonStyle(.bouncy)
    }
}
