import Foundation
import AVFoundation
import UserNotifications

/// 알림·카메라 권한 상태를 관찰 가능한 형태로 제공한다.
@MainActor
@Observable
final class PermissionManager {
    var notificationGranted: Bool = false
    var cameraGranted: Bool = false

    /// 첫 실행 시 두 권한을 함께 요청한다.
    func requestAll() async {
        notificationGranted = await NotificationManager.shared.requestAuthorization()
        cameraGranted = await requestCamera()
    }

    /// 현재 권한 상태를 다시 읽어온다 (설정 앱에서 변경 후 복귀 시).
    func refresh() async {
        let status = await NotificationManager.shared.authorizationStatus()
        notificationGranted = (status == .authorized || status == .provisional || status == .ephemeral)
        cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    private func requestCamera() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}
