import SwiftUI
import SwiftData
import UserNotifications

/// 인증 대상: 어느 날짜의 어느 슬롯인지. 자정 넘김 귀속(기획 §10)을 위해 날짜를 함께 든다.
struct VerifyTarget: Identifiable, Equatable {
    let slot: Slot
    let day: Date
    var id: String { "\(slot.rawValue)-\(day.timeIntervalSince1970)" }
}

/// 알림 탭 시 어떤 슬롯을 인증해야 하는지 뷰 계층에 전달하는 라우터.
@MainActor
@Observable
final class AppRouter {
    /// 알림을 탭해 인증 화면을 열어야 할 대상. 처리 후 nil로 초기화.
    var pendingVerify: VerifyTarget?
}

@main
struct YakmeokpingApp: App {
    @State private var store: MedicationStore
    @State private var permissions = PermissionManager()
    @State private var router = AppRouter()

    private let container: ModelContainer
    private let notificationDelegate: NotificationDelegate

    init() {
        // SwiftData 컨테이너 구성.
        let schema = Schema([MedicationRecord.self, AppSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData 컨테이너 초기화 실패: \(error)")
        }

        let router = AppRouter()
        _router = State(initialValue: router)
        _store = State(initialValue: MedicationStore(context: container.mainContext))

        // 알림 델리게이트 연결 (탭 → 라우터에 슬롯 전달).
        let delegate = NotificationDelegate(router: router)
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(permissions)
                .environment(router)
                .tint(Theme.mainPink)
        }
        .modelContainer(container)
    }
}

/// 로컬 알림 표시/탭 처리.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
        super.init()
    }

    /// 앱이 foreground일 때도 배너·사운드를 표시한다.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// 알림 탭 → 해당 날짜·슬롯 인증 화면으로 직행.
    /// dayKey를 함께 파싱해, 자정을 넘겨 탭해도 원래 슬롯의 날짜로 인증된다 (기획 §10).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let slotRaw = userInfo["slot"] as? String, let slot = Slot(rawValue: slotRaw) else { return }
        let day = (userInfo["dayKey"] as? String).flatMap {
            NotificationScheduling.parseDayKey($0, calendar: Calendar.current)
        } ?? Date()
        await MainActor.run {
            router.pendingVerify = VerifyTarget(slot: slot, day: day)
        }
    }
}
