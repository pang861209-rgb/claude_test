import SwiftUI

/// 카메라 촬영 → 미리보기 → (AI 판독) → 확정 → 축하 화면으로 이어지는 인증 플로우.
/// 특정 날짜·슬롯에 대한 인증을 처리한다 (자정 넘김 시 어제 저녁 귀속 가능).
struct VerificationFlow: View {
    let slot: Slot
    let day: Date
    var store: MedicationStore
    var onClose: () -> Void

    @State private var capturedImage: UIImage?
    @State private var stage: Stage = .camera
    @State private var celebrationMessage: String = ""
    @State private var saveFailed = false
    @State private var checking = false          // AI 판독 중
    @State private var uncertainPhoto = false    // 약이 안 보이는 것 같을 때 (소프트 게이트)

    enum Stage {
        case camera
        case preview
        case celebration
    }

    /// 실기기 카메라 사용 가능 여부. 앨범 폴백은 원칙상 금지 — 불가 시 안내만.
    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            switch stage {
            case .camera:
                if cameraAvailable {
                    CameraPicker(
                        onCapture: { image in
                            capturedImage = image
                            stage = .preview
                        },
                        onCancel: onClose
                    )
                    .ignoresSafeArea()
                } else {
                    cameraUnavailableView
                }

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
        .alert("약이 잘 안 보이는 것 같아요 🥺", isPresented: $uncertainPhoto) {
            Button("다시 찍기") { stage = .camera }
            Button("그래도 인증하기") { finalize() }
        } message: {
            Text("약이나 먹는 모습이 나오게 찍으면 더 좋아요! 그래도 괜찮다면 이대로 인증할 수 있어요.")
        }
    }

    /// 카메라를 쓸 수 없는 환경(시뮬레이터 등). 앨범 선택은 인증 원칙과 어긋나므로 제공하지 않는다.
    private var cameraUnavailableView: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("📷").font(.system(size: 60))
            Text("카메라를 사용할 수 없어요")
                .font(Theme.rounded(20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("약먹핑은 실시간 촬영으로만 인증해요.\n실제 아이폰에서 시도해 주세요!")
                .font(Theme.rounded(15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                onClose()
            } label: {
                Text("닫기")
                    .font(Theme.rounded(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.buttonCornerRadius, style: .continuous)
                            .fill(Theme.heartGradient)
                    )
            }
            .buttonStyle(.bouncy)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
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
                .buttonStyle(.bouncy)
                .disabled(checking)

                Button {
                    confirm()
                } label: {
                    HStack(spacing: 8) {
                        if checking {
                            ProgressView().tint(.white)
                            Text("확인 중...")
                                .font(Theme.rounded(18, weight: .bold))
                        } else {
                            Text("인증 완료 💗")
                                .font(Theme.rounded(18, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.buttonCornerRadius, style: .continuous)
                            .fill(Theme.heartGradient)
                    )
                }
                .buttonStyle(.bouncy)
                .disabled(checking)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    /// 확정 버튼: 기기 내 AI 판독(소프트 게이트) 후 저장.
    /// 약으로 보이면 바로 완료, 애매하면 경고 후 사용자 선택에 맡긴다.
    private func confirm() {
        guard let image = capturedImage, !checking else { return }
        checking = true
        Task {
            let verdict = await PhotoVerifier.verify(image)
            checking = false
            switch verdict {
            case .likelyMedication:
                finalize()
            case .uncertain:
                uncertainPhoto = true
            }
        }
    }

    /// 실제 완료 처리: 사진 저장 → 기록 완료 → 알림 취소 → 축하.
    private func finalize() {
        guard let image = capturedImage else { return }
        if store.complete(slot: slot, on: day, image: image) != nil {
            celebrationMessage = PraiseCopy.randomCelebration()
            stage = .celebration
        } else {
            saveFailed = true
        }
    }
}
