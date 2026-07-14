import SwiftUI

/// 앱의 오리지널 마스코트 "핑핑이" — '사랑의 요정' 무드(핑크·하트·왕관·리본·반짝이)를
/// 자체 디자인으로 구현. 특정 캐릭터 IP를 재현하지 않는다.
///
/// 숨쉬듯 통통 움직이고, 귀가 살랑거리고, 왕관 보석과 볼터치가 반짝이며,
/// 가끔 눈을 깜빡이고, 상태 변화 시 폴짝 뛰며 반응한다.
struct MascotView: View {
    enum Mood {
        case idle      // 평소 (대기)
        case waiting   // 약 먹을 시간 — 신나서
        case happy     // 인증 완료 — 활짝
    }

    var mood: Mood = .idle
    var size: CGFloat = 160

    @State private var bob: CGFloat = 0
    @State private var bobRotate: Double = 0
    @State private var blink = false
    @State private var jump: CGFloat = 0
    @State private var spin: Double = 0
    @State private var earSway: Double = 0
    @State private var gemGlow = false
    @State private var twinkle = false

    var body: some View {
        ZStack {
            ambientTwinkles

            ZStack {
                tiara.offset(y: -size * 0.52)
                ears
                body
            }
            .offset(y: bob + jump)
            .rotationEffect(.degrees(bobRotate + spin))
        }
        .frame(width: size * 1.5, height: size * 1.5)
        .onAppear { startIdle() }
        .onChange(of: mood) { _, newValue in react(newValue) }
    }

    // MARK: - 앰비언트 반짝이

    private var ambientTwinkles: some View {
        ZStack {
            twinkleSymbol("✨", x: -0.5, y: -0.55, delay: 0)
            twinkleSymbol("⭐️", x: 0.55, y: -0.4, delay: 0.5)
            twinkleSymbol("💕", x: -0.58, y: 0.2, delay: 1.0)
            twinkleSymbol("✨", x: 0.56, y: 0.28, delay: 1.5)
        }
    }

    private func twinkleSymbol(_ s: String, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Text(s)
            .font(.system(size: size * 0.13))
            .scaleEffect(twinkle ? 1.0 : 0.4)
            .opacity(twinkle ? 1 : 0)
            .offset(x: size * x, y: size * y)
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(delay), value: twinkle)
    }

    // MARK: - 티아라(왕관)

    private var tiara: some View {
        ZStack {
            TiaraShape()
                .fill(LinearGradient(colors: [Color(hex: 0xFFE39A), Color(hex: 0xF5B93F)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.5, height: size * 0.22)
            HeartShape()
                .fill(RadialGradient(colors: [Color(hex: 0xFF9ECB), Color(hex: 0xE5497F)],
                                     center: .init(x: 0.4, y: 0.35), startRadius: 1, endRadius: size * 0.12))
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(y: -size * 0.12)
                .opacity(gemGlow ? 1 : 0.85)
                .shadow(color: .white.opacity(gemGlow ? 0.9 : 0), radius: 4)
        }
    }

    // MARK: - 귀

    private var ears: some View {
        ZStack {
            earShape
                .rotationEffect(.degrees(-earSway), anchor: .bottom)
                .offset(x: -size * 0.28, y: -size * 0.14)
            ZStack {
                earShape
                ribbon.offset(y: -size * 0.26)
            }
            .rotationEffect(.degrees(earSway), anchor: .bottom)
            .offset(x: size * 0.28, y: -size * 0.14)
        }
    }

    private var earShape: some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: 0xFFB0D8), Theme.pointPurple],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.2, height: size * 0.4)
            Ellipse()
                .fill(Color(hex: 0xFFDCEF))
                .frame(width: size * 0.09, height: size * 0.26)
        }
    }

    private var ribbon: some View {
        ZStack {
            Triangle().fill(Theme.mainPink).frame(width: size * 0.1, height: size * 0.09)
                .rotationEffect(.degrees(-20)).offset(x: -size * 0.05)
            Triangle().fill(Theme.mainPink).frame(width: size * 0.1, height: size * 0.09)
                .rotationEffect(.degrees(20)).offset(x: size * 0.05)
            Circle().fill(Color(hex: 0xFFD1E7)).frame(width: size * 0.05, height: size * 0.05)
        }
    }

    // MARK: - 몸통 + 얼굴

    private var body: some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: 0xFFEAF4), Theme.mainPink],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.92, height: size * 0.84)
                .shadow(color: Theme.mainPink.opacity(0.35), radius: 10, y: 6)

            // 볼터치
            HStack(spacing: size * 0.44) {
                cheek
                cheek
            }
            .offset(y: size * 0.08)

            // 눈
            HStack(spacing: size * 0.22) {
                eye
                eye
            }
            .offset(y: -size * 0.02)

            // 입
            mouth.offset(y: size * 0.14)

            // 가슴 하트 펜던트
            HeartShape()
                .fill(RadialGradient(colors: [Color(hex: 0xFF9ECB), Color(hex: 0xE5497F)],
                                     center: .init(x: 0.4, y: 0.35), startRadius: 1, endRadius: size * 0.1))
                .overlay(HeartShape().stroke(.white, lineWidth: 1.4))
                .frame(width: size * 0.13, height: size * 0.13)
                .offset(y: size * 0.3)
        }
    }

    private var cheek: some View {
        Circle()
            .fill(Color(hex: 0xFF6FB0))
            .frame(width: size * 0.11, height: size * 0.11)
            .opacity(gemGlow ? 0.65 : 0.45)
            .blur(radius: 0.5)
    }

    private var eye: some View {
        Group {
            if blink {
                Capsule()
                    .fill(Color(hex: 0x5A2E45))
                    .frame(width: size * 0.11, height: size * 0.025)
            } else {
                ZStack {
                    Ellipse()
                        .fill(Color(hex: 0x5A2E45))
                        .frame(width: size * 0.11, height: size * 0.16)
                    Circle().fill(.white).frame(width: size * 0.042)
                        .offset(x: -size * 0.02, y: -size * 0.04)
                    Circle().fill(.white.opacity(0.8)).frame(width: size * 0.022)
                        .offset(x: size * 0.02, y: size * 0.03)
                }
            }
        }
    }

    private var mouth: some View {
        let w = (mood == .idle) ? size * 0.1 : size * 0.16
        return Path { p in
            p.move(to: CGPoint(x: -w / 2, y: 0))
            p.addQuadCurve(to: CGPoint(x: w / 2, y: 0), control: CGPoint(x: 0, y: w * 0.7))
        }
        .stroke(Color(hex: 0xD1547F), style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
        .frame(width: w, height: w * 0.7)
    }

    // MARK: - 애니메이션

    private func startIdle() {
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { bob = -size * 0.05 }
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { bobRotate = 1.4 }
        withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { earSway = 5 }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { gemGlow = true }
        twinkle = true
        scheduleBlink()
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 2.5...5.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.08)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.easeInOut(duration: 0.08)) { blink = false }
                scheduleBlink()
            }
        }
    }

    /// 상태 변화 시 폴짝 + 살짝 회전.
    private func react(_ mood: Mood) {
        guard mood != .idle else { return }
        withAnimation(.interpolatingSpring(stiffness: 220, damping: 8)) {
            jump = -size * 0.24
            spin = -7
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 9)) {
                jump = 0
                spin = 0
            }
        }
    }
}

/// 하트 모양 Shape (마스코트·UI 공용).
struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.28))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.28),
                   control1: CGPoint(x: w * 0.5, y: h * -0.05),
                   control2: CGPoint(x: 0, y: h * 0.02))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h),
                   control1: CGPoint(x: 0, y: h * 0.55),
                   control2: CGPoint(x: w * 0.5, y: h * 0.78))
        p.addCurve(to: CGPoint(x: w, y: h * 0.28),
                   control1: CGPoint(x: w * 0.5, y: h * 0.78),
                   control2: CGPoint(x: w, y: h * 0.55))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.28),
                   control1: CGPoint(x: w, y: h * 0.02),
                   control2: CGPoint(x: w * 0.5, y: h * -0.05))
        p.closeSubpath()
        return p
    }
}

/// 티아라(왕관) 지그재그 모양.
struct TiaraShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w * 0.2, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.1))
        p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.55))
        p.addLine(to: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w * 0.9, y: h))
        p.addLine(to: CGPoint(x: w * 0.1, y: h))
        p.closeSubpath()
        return p
    }
}

/// 리본 날개용 삼각형.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
