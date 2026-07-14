import SwiftUI
import SwiftData

/// 슬롯 시각·on/off 설정 + 알림 권한 상태 안내.
/// 변경 시 예약된 알림을 전부 재생성한다.
struct SettingsView: View {
    @Environment(MedicationStore.self) private var store
    @Environment(PermissionManager.self) private var permissions
    @Bindable var settings: AppSettings

    @State private var morningDate: Date = Date()
    @State private var eveningDate: Date = Date()

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Text("설정 🎀")
                        .font(Theme.rounded(24, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)

                    slotCard(slot: .morning, timeBinding: $morningDate,
                             enabled: $settings.morningEnabled)
                    slotCard(slot: .evening, timeBinding: $eveningDate,
                             enabled: $settings.eveningEnabled)

                    permissionCard
                    infoCard
                }
                .padding(20)
            }
        }
        .onAppear {
            morningDate = dateFrom(hour: settings.morningHour, minute: settings.morningMinute)
            eveningDate = dateFrom(hour: settings.eveningHour, minute: settings.eveningMinute)
        }
    }

    private func slotCard(slot: Slot, timeBinding: Binding<Date>, enabled: Binding<Bool>) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(slot.emoji)
                Text(slot.displayName)
                    .font(Theme.rounded(18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Toggle("", isOn: enabled)
                    .labelsHidden()
                    .tint(Theme.mainPink)
                    .onChange(of: enabled.wrappedValue) { _, _ in applyChanges() }
            }

            if enabled.wrappedValue {
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .frame(maxHeight: 120)
                    .onChange(of: timeBinding.wrappedValue) { _, newValue in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        settings.setTime(hour: comps.hour ?? 0, minute: comps.minute ?? 0, for: slot)
                        applyChanges()
                    }
            }
        }
        .cardStyle()
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("알림 권한")
                .font(Theme.rounded(16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            HStack {
                Image(systemName: permissions.notificationGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(permissions.notificationGranted ? Theme.mainPink : Theme.pointPurple)
                Text(permissions.notificationGranted ? "알림이 켜져 있어요 🔔" : "알림이 꺼져 있어요")
                    .font(Theme.rounded(15))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if !permissions.notificationGranted {
                    Button("설정 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(Theme.rounded(14, weight: .bold))
                    .foregroundStyle(Theme.mainPink)
                    .buttonStyle(.bouncy)
                }
            }
        }
        .cardStyle()
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 알아두기")
                .font(Theme.rounded(15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("약을 인증할 때까지 5분마다 알림이 울려요. 사진을 찍으면 그 회차 알림은 바로 멈춰요. 기록은 정직하게 남으니 부담 없이 오늘부터 시작해요! 💕")
                .font(Theme.rounded(13))
                .foregroundStyle(Theme.textSecondary)
        }
        .cardStyle(background: Theme.lightPink.opacity(0.5))
    }

    private func applyChanges() {
        store.save()
        NotificationManager.shared.rescheduleAll(settings: settings)
    }

    private func dateFrom(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
