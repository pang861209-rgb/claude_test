import SwiftUI

/// 앱의 오리지널 마스코트 "핑핑이".
/// 특정 캐릭터 IP를 쓰지 않고, 핑크·하트·왕관·반짝이 무드만 살린 자체 디자인이다.
/// 숨쉬듯 통통 움직이고, 가끔 눈을 깜빡이며, 상태에 따라 반응한다.
struct MascotView: View {
    enum Mood {
        case idle      // 평소 (대기)
        case waiting   // 약 먹을 시간 — 신나서 폴짝
        case happy     // 인증 완료 — 활짝
    }

    var mood: Mood = .idle
    var size: CGFloat = 160

    @State private var bob: CGFloat = 0
    @State private var blink: Bool = false
    @State private var jump: CGFloat = 0
    @State private var sway: Double = 0

    var body: some View {
        ZStack {
            // 왕관 하트 (머리 위 포인트)
            heart
                .fill(Theme.pointPurple)
                .frame(width: size * 0.22, height: size * 0.22)
                .overlay(
                    heart.fill(.white).frame(width: size * 0.08, height: size * 0.08)
                        .offset(x: -size * 0.02, y: -size * 0.02)
                )
                .offset(y: -size * 0.52)
                .rotationEffect(.degrees(sway))

            // 양쪽 귀(둥근 파스텔 puff)
            HStack(spacing: size * 0.62) {
                ear
                ear
            }
            .offset(y: -size * 0.05)

            // 몸통
            ZStack {
                Ellipse()
                    .fill(
                        LinearGradient(colors: [Theme.lightPink, Theme.mainPink],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size * 0.9, height: size * 0.82)
                    .shadow(color: Theme.mainPink.opacity(0.35), radius: 10, y: 6)

                face
            }
        }
        .frame(width: size * 1.4, height: size * 1.4)
        .offset(y: bob + jump)
        .rotationEffect(.degrees(sway * 0.4))
        .onAppear { startIdle() }
        .onChange(of: mood) { _, newValue in react(newValue) }
    }

    // MARK: - 얼굴

    private var face: some View {
        VStack(spacing: size * 0.04) {
            // 눈
            HStack(spacing: size * 0.2) {
                eye
                eye
            }
            // 볼터치 + 입
            HStack(spacing: size * 0.34) {
                blush
                blush
            }
            .overlay(mouth.offset(y: size * 0.02))
        }
        .offset(y: size * 0.02)
    }

    private var eye: some View {
        Group {
            if blink {
                Capsule()
                    .fill(Color(hex: 0x5A3A4A))
                    .frame(width: size * 0.14, height: size * 0.03)
            } else {
                ZStack {
                    Ellipse()
                        .fill(Color(hex: 0x5A3A4A))
                        .frame(width: size * 0.15, height: size * 0.19)
                    // 반짝이 하이라이트
                    Circle().fill(.white).frame(width: size * 0.05, height: size * 0.05)
                        .offset(x: -size * 0.02, y: -size * 0.04)
                    Circle().fill(.white.opacity(0.8)).frame(width: size * 0.025)
                        .offset(x: size * 0.03, y: size * 0.03)
                }
            }
        }
    }

    private var blush: some View {
        Circle()
            .fill(Theme.mainPink.opacity(0.55))
            .frame(width: size * 0.11, height: size * 0.11)
            .blur(radius: 1)
    }

    private var mouth: some View {
        // 상태에 따라 입 모양 변화.
        Group {
            switch mood {
            case .happy, .waiting:
                // 활짝 웃는 입
                Path { p in
                    let w = size * 0.16
                    p.move(to: CGPoint(x: -w/2, y: 0))
                    p.addQuadCurve(to: CGPoint(x: w/2, y: 0), control: CGPoint(x: 0, y: w * 0.7))
                }
                .stroke(Color(hex: 0xD1547F), style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
                .frame(width: size * 0.16, height: size * 0.1)
            case .idle:
                Path { p in
                    let w = size * 0.1
                    p.move(to: CGPoint(x: -w/2, y: 0))
                    p.addQuadCurve(to: CGPoint(x: w/2, y: 0), control: CGPoint(x: 0, y: w * 0.5))
                }
                .stroke(Color(hex: 0xD1547F), style: StrokeStyle(lineWidth: size * 0.018, lineCap: .round))
                .frame(width: size * 0.1, height: size * 0.06)
            }
        }
    }

    private var ear: some View {
        Ellipse()
            .fill(
                LinearGradient(colors: [Theme.mainPink, Theme.pointPurple],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: size * 0.24, height: size * 0.4)
            .rotationEffect(.degrees(sway))
    }

    private var heart: HeartShape { HeartShape() }

    // MARK: - 애니메이션

    private func startIdle() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            bob = -size * 0.03
        }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            sway = 4
        }
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

    /// 상태 변화 시 폴짝 뛰는 반응.
    private func react(_ mood: Mood) {
        guard mood != .idle else { return }
        withAnimation(.interpolatingSpring(stiffness: 220, damping: 8)) {
            jump = -size * 0.22
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.interpolatingSpring(stiffness: 180, damping: 10)) { jump = 0 }
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
