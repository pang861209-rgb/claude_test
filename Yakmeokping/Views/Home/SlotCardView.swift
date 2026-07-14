import SwiftUI

/// 한 슬롯(아침/저녁)의 상태 카드.
struct SlotCardView: View {
    let slot: Slot
    let state: SlotState
    let scheduledTime: DateComponents
    let onTapVerify: () -> Void

    /// 슬롯 표시 상태.
    enum SlotState: Equatable {
        case disabled                       // 슬롯 off
        case waiting                        // 시간 전 대기
        case dueNow                         // 지금 먹을 시간 (미인증, 강조)
        case completed(at: Date, photoPath: String?)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(slot.emoji)
                    .font(.system(size: 30))
                Text(slot.displayName)
                    .font(Theme.rounded(20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(timeString)
                    .font(Theme.rounded(16, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            content
        }
        .cardStyle(background: backgroundColor)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .disabled:
            Label("이 슬롯은 쉬는 중이에요", systemImage: "moon.zzz.fill")
                .font(Theme.rounded(15))
                .foregroundStyle(Theme.textSecondary)

        case .waiting:
            Label(PraiseCopy.randomWaiting(), systemImage: "clock.fill")
                .font(Theme.rounded(15))
                .foregroundStyle(Theme.textSecondary)

        case .dueNow:
            Button(action: onTapVerify) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("지금 인증하기")
                        .font(Theme.rounded(18, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Theme.buttonCornerRadius, style: .continuous)
                        .fill(Theme.heartGradient)
                )
            }
            .buttonStyle(.bouncy)

        case let .completed(at, photoPath):
            HStack(spacing: 14) {
                if let path = photoPath, let image = PhotoStorage.load(relativePath: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Label("완료했어요! 💗", systemImage: "checkmark.seal.fill")
                        .font(Theme.rounded(16, weight: .bold))
                        .foregroundStyle(Theme.mainPink)
                    Text("\(completedTimeString(at)) 인증")
                        .font(Theme.rounded(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .dueNow: return Theme.lightPink
        case .completed: return .white
        default: return .white
        }
    }

    private var timeString: String {
        String(format: "%02d:%02d", scheduledTime.hour ?? 0, scheduledTime.minute ?? 0)
    }

    private func completedTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f.string(from: date)
    }
}
