import SwiftUI

/// 눌렀을 때 통통 튀는 버튼 스타일 + 햅틱. 앱 전역 버튼에 적용해 "반응하는 느낌"을 준다.
struct BouncyButtonStyle: ButtonStyle {
    var haptic: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && haptic { Haptics.tap() }
            }
    }
}

extension ButtonStyle where Self == BouncyButtonStyle {
    static var bouncy: BouncyButtonStyle { BouncyButtonStyle() }
}

/// 뷰가 나타날 때 아래에서 살짝 튀어오르며 등장하는 효과.
struct PopInModifier: ViewModifier {
    var delay: Double = 0
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : 0.85)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    func popIn(delay: Double = 0) -> some View { modifier(PopInModifier(delay: delay)) }
}

/// 시선을 끌기 위해 좌우로 살짝 흔들리는(wiggle) 반복 애니메이션.
/// "지금 먹을 시간" 카드 강조에 사용.
struct WiggleModifier: ViewModifier {
    var active: Bool
    @State private var angle: Double = 0
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear { start() }
            .onChange(of: active) { _, _ in start() }
    }
    private func start() {
        guard active else { angle = 0; return }
        withAnimation(.easeInOut(duration: 0.16).repeatCount(6, autoreverses: true)) {
            angle = 1.6
        }
        // 이후 주기적으로 다시 흔들어 계속 시선을 끈다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if active { angle = 0; start() }
        }
    }
}

extension View {
    func attentionWiggle(active: Bool) -> some View { modifier(WiggleModifier(active: active)) }
}

/// 탭한 지점에서 하트가 뿅 터지는 효과 오버레이.
/// 부모 뷰에 `.heartBurst(trigger:)`로 붙이면 trigger가 바뀔 때마다 하트가 퍼진다.
struct HeartBurstView: View {
    @Binding var trigger: Int
    @State private var bursts: [Burst] = []

    var body: some View {
        ZStack {
            ForEach(bursts) { burst in
                ForEach(burst.hearts) { heart in
                    Text(heart.symbol)
                        .font(.system(size: heart.size))
                        .offset(x: heart.dx, y: heart.dy)
                        .opacity(heart.opacity)
                        .position(burst.origin)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in spawn() }
    }

    private func spawn() {
        let origin = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        var burst = Burst(origin: origin)
        let symbols = ["💗", "💕", "✨", "💖"]
        burst.hearts = (0..<10).map { _ in
            Heart(symbol: symbols.randomElement() ?? "💗", size: CGFloat.random(in: 18...34))
        }
        bursts.append(burst)
        let id = burst.id
        // 애니메이션: 사방으로 퍼지며 사라짐.
        DispatchQueue.main.async {
            guard let index = bursts.firstIndex(where: { $0.id == id }) else { return }
            for i in bursts[index].hearts.indices {
                let angle = Double.random(in: 0...(2 * .pi))
                let dist = CGFloat.random(in: 60...140)
                withAnimation(.easeOut(duration: 0.9)) {
                    bursts[index].hearts[i].dx = cos(angle) * dist
                    bursts[index].hearts[i].dy = sin(angle) * dist - 40
                    bursts[index].hearts[i].opacity = 0
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            bursts.removeAll { $0.id == id }
        }
    }

    struct Burst: Identifiable {
        let id = UUID()
        let origin: CGPoint
        var hearts: [Heart] = []
    }
    struct Heart: Identifiable {
        let id = UUID()
        let symbol: String
        let size: CGFloat
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        var opacity: Double = 1
    }
}
