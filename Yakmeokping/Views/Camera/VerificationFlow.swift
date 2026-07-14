import SwiftUI

/// 카메라 촬영 → 미리보기 → 확정 → 축하 화면으로 이어지는 인증 플로우.
/// 특정 슬롯에 대한 인증을 처리한다.
struct VerificationFlow: View {
    let slot: Slot
    let day: Date
    var store: MedicationStore
    var onClose: () -> Void

    @State private var capturedImage: UIImage?
    @State private var stage: Stage = .camera
    @State private var celebrationMessage: String = ""
    @State private var saveFailed = false

    enum Stage {
        case camera
        case preview
        case celebration
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            switch stage {
            case .camera:
                CameraPicker(
                    onCapture: { image in
                        capturedImage = image
                        stage = .preview
                    },
                    onCancel: onClose
                )
                .ignoresSafeArea()

            case .preview:
                previewView

            case .celebration:
                CelebrationView(message: celebrationMessage) {
                    onClose()
                }
            }
        }
        .alert("사진 저장에 실패했어요 🥲", isPresented: $saveFailed) {
            Button("다시 찍기") { stage = .camera }
            Button("닫기", role: .cancel) { onClose() }
        } message: {
            Text("저장 공간을 확인하고 다시 시도해 주세요.")
        }
    }

    private var previewView: some View {
        VStack(spacing: 24) {
            Text("이 사진으로 인증할까요? 💕")
                .font(Theme.rounded(22, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 24)

            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
                    .shadow(color: Theme.mainPink.opacity(0.2), radius: 12, y: 6)
                    .padding(.horizontal, 24)
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    capturedImage = nil
                    stage = .camera
                } label: {
                    Text("다시 찍기")
                        .font(Theme.rounded(18, weight: .semibold))
                        .foregroundStyle(Theme.mainPink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.buttonCornerRadius, style: .continuous)
                                .stroke(Theme.mainPink, lineWidth: 2)
                        )
                }

                Button {
                    confirm()
                } label: {
                    Text("인증 완료 💗")
                        .font(Theme.rounded(18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.buttonCornerRadius, style: .continuous)
                                .fill(Theme.heartGradient)
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func confirm() {
        guard let image = capturedImage else { return }
        if store.complete(slot: slot, on: day, image: image) != nil {
            celebrationMessage = PraiseCopy.randomCelebration()
            stage = .celebration
        } else {
            saveFailed = true
        }
    }
}
