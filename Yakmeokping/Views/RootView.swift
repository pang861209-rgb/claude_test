import SwiftUI
import SwiftData

/// 하단 탭 컨테이너: 홈 / 캘린더 / 설정. 첫 실행 시 온보딩이 먼저 뜬다.
struct RootView: View {
    @Environment(MedicationStore.self) private var store
    @Environment(PermissionManager.self) private var permissions
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var settings: AppSettings?

    var body: some View {
        Group {
            if let settings {
                if hasOnboarded {
                    TabView {
                        HomeView(settings: settings)
                            .tabItem { Label("홈", systemImage: "house.fill") }

                        CalendarView()
                            .tabItem { Label("캘린더", systemImage: "calendar") }

                        SettingsView(settings: settings)
                            .tabItem { Label("설정", systemImage: "gearshape.fill") }
                    }
                    .tint(Theme.mainPink)
                } else {
                    OnboardingView(settings: settings) {
                        Task { await finishOnboarding(settings) }
                    }
                }
            } else {
                // 설정 로딩 중 스플래시.
                ZStack {
                    Theme.softGradient.ignoresSafeArea()
                    CharacterView(mood: .idle, size: 160)
                }
            }
        }
        .task { await bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await onForeground() } }
        }
    }

    /// 최초 진입: 설정 로드 + 오늘 기록 보장. 권한 요청은 온보딩에서만 (프라이밍 원칙).
    private func bootstrap() async {
        let loaded = store.loadOrCreateSettings()
        settings = loaded
        store.ensureRecords()

        guard hasOnboarded else { return }
        await permissions.refresh()
        NotificationManager.shared.rescheduleAll(settings: loaded)
    }

    /// 온보딩 완료: 이 시점에서만 시스템 권한 팝업을 띄운다.
    private func finishOnboarding(_ settings: AppSettings) async {
        store.save()
        await permissions.requestAll()
        await permissions.refresh()
        NotificationManager.shared.rescheduleAll(settings: settings)
        withAnimation { hasOnboarded = true }
    }

    /// foreground 진입: 권한 갱신 + 미인증 슬롯 알림 연장 (기획 §6).
    private func onForeground() async {
        guard hasOnboarded, let settings else { return }
        await permissions.refresh()
        store.ensureRecords()

        let now = Date()
        for slot in Slot.allCases where settings.isEnabled(slot) {
            let record = store.record(for: slot, on: now)
            if record?.status != .completed {
                NotificationManager.shared.extendIfNeeded(for: slot, on: now, time: settings.time(for: slot), now: now)
            }
        }
    }
}
