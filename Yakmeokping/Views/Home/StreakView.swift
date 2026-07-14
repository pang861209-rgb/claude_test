import SwiftUI

/// 연속 복약 일수 뱃지. 하루 2회를 모두 인증한 날만 카운트.
struct StreakView: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("🔥")
                .font(.system(size: 26))
            if streak > 0 {
                Text("연속 \(streak)일째 성공!")
                    .font(Theme.rounded(18, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("오늘부터 시작해봐요! 💕")
                    .font(Theme.rounded(17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            Capsule().fill(Theme.heartGradient)
                .shadow(color: Theme.mainPink.opacity(0.3), radius: 8, y: 4)
        )
    }
}
