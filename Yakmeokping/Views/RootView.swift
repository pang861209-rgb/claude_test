import SwiftUI
import SwiftData

/// 하단 탭 컨테이너: 홈 / 캘린더 / 설정.
struct RootView: View {
    @Environment(MedicationStore.self) private var store
    @Environment(PermissionManager.self) private var permissions
    @Environment(\.scenePhase) private var scenePhase

    @State private var settings: AppSettings?

    var body: some View {
        Group {
            if let settings {
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
                // 설정 로딩 중 스플래시.
                ZStack {
                    Theme.softGradient.ignoresSafeArea()
                    MascotView(mood: .idle, size: 160)
                }
            }
        }
        .task { await bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await onForeground() } }
        }
    }

    /// 최초 진입: 설정 로드, 권한 요청, 오늘 기록 보장, 알림 재예약.
    private func bootstrap() async {
        let loaded = store.loadOrCreateSettings()
        settings = loaded
        store.ensureRecords()

        await permissions.requestAll()
        await permissions.refresh()

        // 오늘치 알림 (재)예약.
        NotificationManager.shared.rescheduleAll(settings: loaded)
    }

    /// foreground 진입: 권한 갱신 + 미인증 슬롯 알림 연장 (기획서 §6).
    private func onForeground() async {
        await permissions.refresh()
        guard let settings else { return }
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
