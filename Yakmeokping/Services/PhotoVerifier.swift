import UIKit
import Vision

/// 인증 사진이 "약 관련 사진"으로 보이는지 기기 내에서 판독한다.
///
/// - Apple Vision의 내장 이미지 분류(`VNClassifyImageRequest`)를 사용 — 서버·네트워크·비용 없음, 사진이 기기를 떠나지 않음.
/// - **소프트 게이트 전략**: 판독은 참고용 경고까지만. 확신이 없으면 사용자가 "그래도 인증"을 선택할 수 있다.
///   (신뢰 기반 앱에서 오탐으로 정직한 인증을 막는 것이 판독 실패보다 더 나쁘기 때문)
enum PhotoVerifier {

    enum Verdict {
        case likelyMedication   // 약/의약품 관련으로 보임
        case uncertain          // 판별 불가 (경고 후 진행 허용)
    }

    /// 내장 분류 라벨 중 "약 먹는 장면"과 연관된 키워드.
    /// Vision 분류기의 라벨은 영문 소문자 식별자로 내려온다.
    private static let keywords: [String] = [
        "pill", "medicine", "medication", "capsule", "tablet",
        "vitamin", "drug", "pharmacy", "blister", "syrup",
        "bottle", "cup", "glass", "water", "hand", "mouth", "face"
        // hand/mouth/face/cup: "약을 입에 넣는 셀피" 패턴을 넓게 수용하기 위한 보조 신호
    ]

    /// 보조 신호(손/컵 등)만 잡혔을 때 요구하는 최소 신뢰도.
    private static let weakConfidence: VNConfidence = 0.15
    /// 핵심 신호(pill/medicine 등)에 요구하는 최소 신뢰도.
    private static let strongConfidence: VNConfidence = 0.05

    private static let strongKeywords: Set<String> = [
        "pill", "medicine", "medication", "capsule", "tablet", "vitamin", "drug", "pharmacy", "blister", "syrup"
    ]

    /// 사진을 분류해 판정을 반환한다. 판독 자체가 실패하면 진행을 막지 않도록 `.likelyMedication`을 반환(fail-open).
    static func verify(_ image: UIImage) async -> Verdict {
        guard let cgImage = image.cgImage else { return .likelyMedication }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    continuation.resume(returning: judge(observations))
                } catch {
                    // 판독 실패는 인증을 막지 않는다 (신뢰 기반).
                    continuation.resume(returning: .likelyMedication)
                }
            }
        }
    }

    private static func judge(_ observations: [VNClassificationObservation]) -> Verdict {
        for obs in observations {
            let id = obs.identifier.lowercased()
            let isStrong = strongKeywords.contains(where: { id.contains($0) })
            let isWeak = keywords.contains(where: { id.contains($0) })
            if isStrong && obs.confidence >= strongConfidence { return .likelyMedication }
            if isWeak && obs.confidence >= weakConfidence { return .likelyMedication }
        }
        return .uncertain
    }
}
