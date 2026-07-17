import SwiftUI

/// 첫 실행 온보딩 3장: 핑핑이 인사 → 동작 방식 설명 → 시간 설정 + 권한 프라이밍.
/// 시스템 권한 팝업은 사용자가 "알림 받고 시작하기"를 누른 뒤에만 뜬다 (UX 리뷰 §05-1).
struct OnboardingView: View {
    @Bindable var settings: AppSettings
    /// 시간 저장이 끝나고 사용자가 시작을 눌렀을 때 호출. 권한 요청은 호출부(RootView)가 수행.
    var onFinish: () -> Void

    @State private var page = 0
    @State private var morningDate = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var eveningDate = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()

    var body: some View {
        ZStack {
            Theme.softGradient.ignoresSafeArea()

            TabView(selection: $page) {
                greetingPage.tag(0)
                howItWorksPage.tag(1)
                setupPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    // MARK: - 1장: 인사

    private var greetingPage: some View {
        VStack(spacing: 24) {
            Spacer()
            CharacterView(mood: .happy, size: 170)
                .frame(height: 260)
            Text("안녕! 나는 \(Branding.characterName)야 💗")
                .font(Theme.rounded(26, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("매일 약 먹는 시간,\n혼자 챙기기 힘들었지?\n이제 내가 같이 챙겨줄게!")
                .font(Theme.rounded(17))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
            Spacer()
            nextButton("반가워! 👋") { page = 1 }
            Spacer().frame(height: 60)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - 2장: 동작 방식

    private var howItWorksPage: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("이렇게 함께해요")
                .font(Theme.rounded(24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            VStack(spacing: 14) {
                explainRow(icon: "🔔", title: "약 시간에 알려줄게",
                           detail: "인증할 때까지 5분마다 계속! 끄는 방법은 인증뿐이야 😉")
                explainRow(icon: "📸", title: "먹는 모습을 한 장 찰칵",
                           detail: "사진을 찍으면 그 회차 알림이 바로 멈춰")
                explainRow(icon: "💗", title: "캘린더에 하트가 쌓여",
                           detail: "연속 성공 기록도, 지난 인증 사진도 다시 볼 수 있어")
            }
            Spacer()
            nextButton("좋아, 알겠어!") { page = 2 }
            Spacer().frame(height: 60)
        }
        .padding(.horizontal, 28)
    }

    private func explainRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(icon).font(.system(size: 30))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.rounded(16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(Theme.rounded(14))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.75)))
    }

    // MARK: - 3장: 시간 설정 + 권한 프라이밍

    private var setupPage: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("약 먹는 시간을 알려줘 ⏰")
                .font(Theme.rounded(23, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("나중에 설정에서 언제든 바꿀 수 있어요")
                .font(Theme.rounded(14))
                .foregroundStyle(Theme.textSecondary)

            timeRow(emoji: "🌅", label: "아침 약", selection: $morningDate)
            timeRow(emoji: "🌙", label: "저녁 약", selection: $eveningDate)

            Spacer()

            Text("시작하려면 알림 허용이 필요해요.\n\(Branding.characterName)가 약 시간을 알려드려도 될까요? 🥺")
                .font(Theme.rounded(14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            nextButton("알림 받고 시작하기 💗") { finish() }
            Spacer().frame(height: 60)
        }
        .padding(.horizontal, 28)
    }

    private func timeRow(emoji: String, label: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(emoji).font(.system(size: 24))
            Text(label)
                .font(Theme.rounded(17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(Theme.mainPink)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.85)))
    }

    private func nextButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.pop()
            withAnimation { action() }
        } label: {
            Text(title)
                .font(Theme.rounded(18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: Theme.buttonCornerRadius, style: .continuous)
                        .fill(Theme.heartGradient)
                        .shadow(color: Theme.mainPink.opacity(0.35), radius: 10, y: 5)
                )
        }
        .buttonStyle(.bouncy)
    }

    private func finish() {
        let cal = Calendar.current
        let m = cal.dateComponents([.hour, .minute], from: morningDate)
        let e = cal.dateComponents([.hour, .minute], from: eveningDate)
        settings.setTime(hour: m.hour ?? 8, minute: m.minute ?? 0, for: .morning)
        settings.setTime(hour: e.hour ?? 20, minute: e.minute ?? 0, for: .evening)
        onFinish()
    }
}
