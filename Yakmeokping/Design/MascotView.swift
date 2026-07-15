import SwiftUI

/// 앱의 오리지널 마스코트 "핑핑이" — '사랑의 요정' 무드(핑크·하트·왕관·리본·반짝이)를
/// 자체 디자인으로 구현. 특정 캐릭터 IP를 재현하지 않는다.
///
/// 말랑한 3D 젤리 질감(radial 하이라이트), 크고 촉촉한 눈(홍채 그라데이션 + 하이라이트 3개),
/// 앞머리 곱슬, 하트 코, ω 미소. 숨쉬듯 통통 움직이고, 귀가 살랑거리고,
/// 보석·볼터치가 반짝이며, 상태 변화 시 폴짝 뛰며 반응한다.
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
            // 뒤 반짝이 후광
            Circle()
                .fill(Color(hex: 0xFFD9EC).opacity(0.35))
                .frame(width: size * 1.1, height: size * 1.1)

            ambientTwinkles

            ZStack {
                tiara.offset(y: -size * 0.52)
                ears
                torso
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
                .fill(LinearGradient(colors: [Color(hex: 0xFFEDB3), Color(hex: 0xFFD76E), Color(hex: 0xF0AC2E)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.5, height: size * 0.22)
            HeartShape()
                .fill(gemGradient(radius: size * 0.12))
                .overlay(HeartShape().stroke(.white, lineWidth: 1.2))
                .frame(width: size * 0.17, height: size * 0.17)
                .offset(y: -size * 0.12)
                .opacity(gemGlow ? 1 : 0.85)
                .shadow(color: .white.opacity(gemGlow ? 0.9 : 0), radius: 4)
        }
    }

    private func gemGradient(radius: CGFloat) -> RadialGradient {
        RadialGradient(colors: [Color(hex: 0xFFC4DF), Color(hex: 0xFF7AB8), Color(hex: 0xDE3D7B)],
                       center: .init(x: 0.38, y: 0.3), startRadius: 1, endRadius: radius)
    }

    // MARK: - 귀

    private var ears: some View {
        ZStack {
            earShape
                .rotationEffect(.degrees(-earSway), anchor: .bottom)
                .offset(x: -size * 0.29, y: -size * 0.16)
            ZStack {
                earShape
                ribbon.offset(y: -size * 0.27)
            }
            .rotationEffect(.degrees(earSway), anchor: .bottom)
            .offset(x: size * 0.29, y: -size * 0.16)
        }
    }

    private var earShape: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: 0xFFD3E9), Color(hex: 0xFFAAD6), Color(hex: 0xE48BD9)],
                                     center: .init(x: 0.4, y: 0.25), startRadius: 1, endRadius: size * 0.3))
                .frame(width: size * 0.22, height: size * 0.43)
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: 0xFFF0F7), Color(hex: 0xFFC9E4)],
                                     center: .init(x: 0.45, y: 0.3), startRadius: 1, endRadius: size * 0.18))
                .frame(width: size * 0.1, height: size * 0.28)
            // 윤기 하이라이트
            Ellipse()
                .fill(.white.opacity(0.5))
                .frame(width: size * 0.05, height: size * 0.1)
                .offset(x: -size * 0.05, y: -size * 0.12)
        }
    }

    private var ribbon: some View {
        ZStack {
            Circle().fill(Theme.mainPink)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: -size * 0.055)
            Circle().fill(Theme.mainPink)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: size * 0.055)
            Circle().fill(Color(hex: 0xFFD1E7))
                .overlay(Circle().stroke(Theme.mainPink, lineWidth: 1))
                .frame(width: size * 0.055, height: size * 0.055)
        }
    }

    // MARK: - 몸통 + 얼굴 (말랑 젤리)

    private var torso: some View {
        ZStack {
            // 젤리 질감 몸통: 좌상단 하이라이트 radial
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: 0xFFF6FA), Color(hex: 0xFFDFEF), Color(hex: 0xFF9FCE)],
                                     center: .init(x: 0.38, y: 0.28), startRadius: 1, endRadius: size * 0.62))
                .frame(width: size * 0.94, height: size * 0.86)
                .shadow(color: Theme.mainPink.opacity(0.35), radius: 10, y: 6)

            // 윤기 하이라이트
            Ellipse()
                .fill(.white.opacity(0.55))
                .frame(width: size * 0.24, height: size * 0.12)
                .rotationEffect(.degrees(-24))
                .offset(x: -size * 0.24, y: -size * 0.3)

            // 앞머리 곱슬
            CurlShape()
                .stroke(LinearGradient(colors: [Theme.mainPink, Color(hex: 0xF25FA4)],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round))
                .frame(width: size * 0.2, height: size * 0.19)
                .offset(x: -size * 0.06, y: -size * 0.37)

            // 볼터치
            HStack(spacing: size * 0.46) {
                cheek
                cheek
            }
            .offset(y: size * 0.1)

            // 눈썹
            HStack(spacing: size * 0.24) {
                browShape(flip: false)
                browShape(flip: true)
            }
            .offset(y: -size * 0.16)

            // 눈
            HStack(spacing: size * 0.14) {
                eye(mirrored: false)
                eye(mirrored: true)
            }
            .offset(y: -size * 0.01)

            // 하트 코
            HeartShape()
                .fill(Color(hex: 0xE86FA8))
                .frame(width: size * 0.055, height: size * 0.05)
                .offset(y: size * 0.1)

            // ω 미소
            omegaMouth.offset(y: size * 0.16)

            // 크림색 배 패치
            Ellipse()
                .fill(Color(hex: 0xFFF3F9).opacity(0.9))
                .frame(width: size * 0.4, height: size * 0.22)
                .offset(y: size * 0.28)

            // 가슴 하트 펜던트
            HeartShape()
                .fill(gemGradient(radius: size * 0.1))
                .overlay(HeartShape().stroke(.white, lineWidth: 1.6))
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(y: size * 0.27)
        }
    }

    private var cheek: some View {
        Ellipse()
            .fill(Color(hex: 0xFF6FB0))
            .frame(width: size * 0.13, height: size * 0.085)
            .opacity(gemGlow ? 0.65 : 0.45)
            .blur(radius: 0.5)
    }

    private func browShape(flip: Bool) -> some View {
        BrowShape()
            .stroke(Color(hex: 0xC97BA4).opacity(0.7),
                    style: StrokeStyle(lineWidth: size * 0.014, lineCap: .round))
            .frame(width: size * 0.11, height: size * 0.035)
            .scaleEffect(x: flip ? -1 : 1)
    }

    /// 크고 촉촉한 눈: 흰자 + 홍채 그라데이션 + 동공 + 하이라이트 3개.
    private func eye(mirrored: Bool) -> some View {
        Group {
            if blink {
                Capsule()
                    .fill(Color(hex: 0x5A2E45))
                    .frame(width: size * 0.13, height: size * 0.025)
            } else {
                ZStack {
                    Ellipse().fill(.white)
                        .frame(width: size * 0.155, height: size * 0.19)
                    Ellipse()
                        .fill(RadialGradient(colors: [Color(hex: 0xE05A9E), Color(hex: 0xA5326E), Color(hex: 0x4A1230)],
                                             center: .init(x: 0.42, y: 0.34), startRadius: 1, endRadius: size * 0.12))
                        .frame(width: size * 0.125, height: size * 0.16)
                    Ellipse().fill(Color(hex: 0x2A0818))
                        .frame(width: size * 0.065, height: size * 0.085)
                        .offset(y: size * 0.012)
                    // 하이라이트: 큰 것 + 작은 것 + 핑크 반사
                    Circle().fill(.white)
                        .frame(width: size * 0.05)
                        .offset(x: -size * 0.025, y: -size * 0.045)
                    Circle().fill(.white.opacity(0.9))
                        .frame(width: size * 0.026)
                        .offset(x: size * 0.025, y: size * 0.035)
                    Circle().fill(Color(hex: 0xFFB6DA).opacity(0.8))
                        .frame(width: size * 0.016)
                        .offset(x: -size * 0.015, y: size * 0.05)
                }
                .scaleEffect(x: mirrored ? -1 : 1)
            }
        }
    }

    private var omegaMouth: some View {
        let w = (mood == .idle) ? size * 0.12 : size * 0.17
        return OmegaMouthShape()
            .stroke(Color(hex: 0xD1547F),
                    style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
            .frame(width: w, height: w * 0.35)
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

/// 앞머리 곱슬(소용돌이) 모양. 프레임 안에 "6"자형 컬을 그린다.
struct CurlShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.83, y: h * 0.23))
        p.addCurve(to: CGPoint(x: w * 0.25, y: h * 0.77),
                   control1: CGPoint(x: w * 0.33, y: h * 0.05),
                   control2: CGPoint(x: 0, y: h * 0.41))
        p.addCurve(to: CGPoint(x: w * 0.75, y: h * 0.64),
                   control1: CGPoint(x: w * 0.42, y: h * 1.0),
                   control2: CGPoint(x: w * 0.75, y: h * 0.91))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.59),
                   control1: CGPoint(x: w * 0.75, y: h * 0.45),
                   control2: CGPoint(x: w * 0.54, y: h * 0.41))
        return p
    }
}

/// 눈썹 곡선.
struct BrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height))
        p.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height * 0.6),
                       control: CGPoint(x: rect.width * 0.5, y: -rect.height * 0.4))
        return p
    }
}

/// ω(오메가) 미소 모양: 물결 두 개.
struct OmegaMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h * 0.2))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.2),
                       control: CGPoint(x: w * 0.25, y: h * 1.2))
        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.2),
                       control: CGPoint(x: w * 0.75, y: h * 1.2))
        return p
    }
}

/// 리본 날개용 삼각형. (다른 뷰에서 재사용 가능)
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
