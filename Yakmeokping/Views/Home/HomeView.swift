import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(MedicationStore.self) private var store
    @Environment(PermissionManager.self) private var permissions
    @Environment(AppRouter.self) private var router
    let settings: AppSettings

    @State private var records: [Slot: MedicationRecord] = [:]
    @State private var streak: Int = 0
    @State private var verifying: VerifyTarget?
    @State private var heartTrigger: Int = 0
    @State private var now: Date = Date()

    /// 조기 인증 허용 시간 (슬롯 시각 2시간 전부터).
    private let earlyWindow: TimeInterval = 2 * 60 * 60

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

                    // 자정을 넘긴 새벽: 어제 저녁이 미인증이면 귀속 인증 카드 노출 (기획 §10)
                    if let lateTarget = lateNightTarget {
                        LateNightCard {
                            Haptics.pop()
                            verifying = lateTarget
                        }
                        .popIn(delay: 0.12)
                    }

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
        .onChange(of: router.pendingVerify) { _, _ in handlePendingRoute() }
        .fullScreenCover(item: $verifying) { target in
            VerificationFlow(slot: target.slot, day: target.day, store: store) {
                verifying = nil
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
            return .completed(at: at, photoPath: record.photoPath, late: record.isLate)
        }
        // pending: 시간 도래 여부 (T−2h부터는 조기 인증 허용)
        if let base = NotificationScheduling.baseFireDate(for: slot, on: now, settings: settings.time(for: slot), calendar: store.calendar) {
            if now >= base { return .dueNow }
            if now >= base.addingTimeInterval(-earlyWindow) { return .soon }
        }
        return .waiting
    }

    /// 새벽(03시 이전)이고 어제 저녁이 미인증이면, 어제 저녁으로 귀속되는 인증 대상 반환.
    private var lateNightTarget: VerifyTarget? {
        guard settings.eveningEnabled,
              let yesterday = NotificationScheduling.lateNightAttributedDay(now: now, calendar: store.calendar) else { return nil }
        let record = store.record(for: .evening, on: yesterday)
        guard record == nil || record?.status == .pending else { return nil }
        return VerifyTarget(slot: .evening, day: yesterday)
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
        verifying = VerifyTarget(slot: slot, day: now)
    }

    /// 알림 탭으로 전달된 대상이 있으면 카메라 화면을 연다.
    private func handlePendingRoute() {
        guard let target = router.pendingVerify else { return }
        router.pendingVerify = nil
        // 이미 완료된 슬롯이면 무시.
        if let record = store.record(for: target.slot, on: target.day), record.status == .completed { return }
        verifying = target
    }

    private func refresh() {
        records = store.ensureRecords(for: now)
        streak = store.currentStreak(asOf: now)
        // 위젯에 오늘 상태 게시.
        WidgetBridge.publish(records: records, streak: streak, settings: settings,
                             calendar: store.calendar, now: now)
    }

    private var todayString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: now)
    }
}

/// 자정을 넘긴 새벽에 어제 저녁 약을 인증할 수 있게 해주는 카드 (기획 §10).
/// 인증하면 "오늘"이 아니라 "어제 저녁" 기록으로 귀속된다.
struct LateNightCard: View {
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🌙").font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text("어제 저녁 약, 지금 먹었나요?")
                        .font(Theme.rounded(16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("늦어도 괜찮아요! 어제 기록으로 남겨드릴게요")
                        .font(Theme.rounded(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            Button(action: onTap) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("어제 저녁 약 인증하기")
                        .font(Theme.rounded(16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.buttonCornerRadius, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.pointPurple, Theme.mainPink],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                )
            }
            .buttonStyle(.bouncy)
        }
        .cardStyle(background: Color(hex: 0xF3E8FF).opacity(0.7))
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
