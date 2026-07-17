import SwiftUI

/// 마스코트 표시 뷰 — 솜솜시티 캐릭터 이미지(애셋)가 있으면 그걸 쓰고,
/// 없으면 기존 코드 드로잉 마스코트(MascotView)로 폴백한다.
///
/// 캐릭터 이미지는 작가 시트 기반으로 생성해 애셋에 넣는다 (SOMSOM_GUIDE.md).
/// 이미지에도 기존과 동일한 생동감(숨쉬기 통통, 무드 반응 점프)을 적용한다.
struct CharacterView: View {
    var mood: MascotView.Mood = .idle
    var size: CGFloat = 160

    @State private var bob: CGFloat = 0
    @State private var jump: CGFloat = 0
    @State private var spin: Double = 0

    private var characterMood: CharacterMood {
        switch mood {
        case .idle: return .idle
        case .waiting: return .waiting
        case .happy: return .happy
        }
    }

    /// 무드 이미지 → 없으면 idle 이미지 → 그것도 없으면 nil(폴백).
    private var characterImage: UIImage? {
        UIImage(named: Branding.characterAsset(for: characterMood))
            ?? UIImage(named: Branding.characterAsset(for: .idle))
    }

    var body: some View {
        if let image = characterImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size * 1.3, height: size * 1.3)
                .offset(y: bob + jump)
                .rotationEffect(.degrees(spin))
                .onAppear { startIdle() }
                .onChange(of: mood) { _, newValue in react(newValue) }
        } else {
            // 시트 기반 이미지가 아직 없으면 기존 마스코트로 폴백.
            MascotView(mood: mood, size: size)
        }
    }

    private func startIdle() {
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            bob = -size * 0.04
        }
    }

    private func react(_ mood: MascotView.Mood) {
        guard mood != .idle else { return }
        withAnimation(.interpolatingSpring(stiffness: 220, damping: 8)) {
            jump = -size * 0.22
            spin = -6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 9)) {
                jump = 0
                spin = 0
            }
        }
    }
}
