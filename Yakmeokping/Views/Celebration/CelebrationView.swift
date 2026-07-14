import SwiftUI

/// 인증 완료 후 표시되는 축하 화면.
/// 하트·반짝이 파티클 + 랜덤 칭찬 문구. 2초 후 자동으로 닫힌다.
struct CelebrationView: View {
    let message: String
    var onFinish: () -> Void

    @State private var particles: [Particle] = []
    @State private var titleScale: CGFloat = 0.3
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            Theme.softGradient
                .ignoresSafeArea()

            // 파티클
            ForEach(particles) { particle in
                Text(particle.symbol)
                    .font(.system(size: particle.size))
                    .opacity(particle.opacity)
                    .position(x: particle.x, y: particle.y)
                    .rotationEffect(.degrees(particle.rotation))
            }

            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 80))
                    .scaleEffect(titleScale)
                Text(message)
                    .font(Theme.rounded(30, weight: .bold))
                    .foregroundStyle(Theme.mainPink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .scaleEffect(titleScale)
                    .opacity(titleOpacity)
            }
        }
        .onAppear {
            spawnParticles()
            animateParticles()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                titleScale = 1.0
                titleOpacity = 1.0
            }
            // 2초 후 자동 복귀.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onFinish()
            }
        }
    }

    private func spawnParticles() {
        let symbols = ["💗", "💕", "✨", "⭐️", "🎀", "💖", "🌸"]
        let screen = UIScreen.main.bounds
        particles = (0..<40).map { _ in
            Particle(
                symbol: symbols.randomElement() ?? "💗",
                x: CGFloat.random(in: 0...screen.width),
                y: CGFloat.random(in: screen.height...(screen.height + 120)),
                size: CGFloat.random(in: 20...42),
                opacity: 1.0,
                rotation: Double.random(in: 0...360)
            )
        }
    }

    private func animateParticles() {
        let screen = UIScreen.main.bounds
        for index in particles.indices {
            let duration = Double.random(in: 1.4...2.2)
            withAnimation(.easeOut(duration: duration)) {
                particles[index].y = CGFloat.random(in: -60...(screen.height * 0.4))
                particles[index].x += CGFloat.random(in: -60...60)
                particles[index].rotation += Double.random(in: -180...180)
                particles[index].opacity = 0
            }
        }
    }

    struct Particle: Identifiable {
        let id = UUID()
        let symbol: String
        var x: CGFloat
        var y: CGFloat
        let size: CGFloat
        var opacity: Double
        var rotation: Double
    }
}
