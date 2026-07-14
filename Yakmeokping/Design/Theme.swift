import SwiftUI

/// 앱 전역 디자인 토큰 (기획서 §9).
/// 특정 캐릭터 IP를 쓰지 않고 핑크·파스텔·하트 무드만 구현.
enum Theme {
    // MARK: - 컬러
    static let mainPink = Color(hex: 0xFF8FC7)
    static let lightPink = Color(hex: 0xFFE1F0)
    static let pointPurple = Color(hex: 0xC89AF5)
    static let cream = Color(hex: 0xFFF8FB)

    static let textPrimary = Color(hex: 0x5A4A55)
    static let textSecondary = Color(hex: 0x9B8A94)

    /// 파스텔 그라데이션 (배경/버튼용).
    static let softGradient = LinearGradient(
        colors: [lightPink, Color(hex: 0xF3E5FF)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heartGradient = LinearGradient(
        colors: [mainPink, pointPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - 모양
    static let cardCornerRadius: CGFloat = 28
    static let buttonCornerRadius: CGFloat = 24

    // MARK: - 폰트 (SF Pro Rounded)
    static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    /// 16진수 리터럴(0xRRGGBB)로 색 생성.
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// 카드 컨테이너 스타일.
struct CardModifier: ViewModifier {
    var background: Color = .white
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(background)
                    .shadow(color: Theme.mainPink.opacity(0.15), radius: 12, x: 0, y: 6)
            )
    }
}

extension View {
    func cardStyle(background: Color = .white) -> some View {
        modifier(CardModifier(background: background))
    }
}

/// 응원·칭찬 톤의 랜덤 문구 모음.
enum PraiseCopy {
    /// 축하 화면 문구 (매번 다르게).
    static let celebration = [
        "오늘도 해냈어! 💕",
        "완전 대단해! 🌟",
        "약속 지킨 너 최고야! 🏆",
        "반짝반짝 성공! ✨",
        "참 잘했어요~ 🎀",
        "건강해지는 중! 💊💗",
        "역시 믿었어! 🥰",
        "하트 뿅뿅 보낼게! 💖"
    ]

    static func randomCelebration() -> String {
        celebration.randomElement() ?? "참 잘했어요! 💕"
    }

    /// 미완료 슬롯의 대기 문구 (질책 금지).
    static let waiting = [
        "약이 기다리고 있어요! 🥰",
        "인증샷 한 장이면 끝! 📸",
        "지금이 딱 좋은 타이밍이에요 💕"
    ]

    static func randomWaiting() -> String {
        waiting.randomElement() ?? "약이 기다리고 있어요! 🥰"
    }
}
