import Foundation

/// 솜솜 약먹핑 브랜딩 상수.
/// 이 브랜치는 사용자 소유 IP '솜솜시티'의 캐릭터 **끼토(분홍 토끼)**를 마스코트로 사용한다.
///
/// ⚠️ 캐릭터 아트 규칙 (작가 시트 기준):
/// - 캐릭터 이미지는 코드로 그리지 않는다. 원본 시트(sheet_kkito.png)를 이미지 입력으로 넣어
///   생성한 PNG만 사용한다 (재디자인 금지, 색은 시트에서 샘플링).
/// - 생성/적용 방법은 저장소 루트의 SOMSOM_GUIDE.md 참고.
/// - 이미지를 넣기 전까지는 기존 코드 드로잉 마스코트(핑핑이)가 폴백으로 표시된다.
enum Branding {
    /// 앱 표시 이름.
    static let appName = "솜솜 약먹핑"

    /// 메인 마스코트 이름 (알림·온보딩 문구의 화자).
    static let characterName = "끼토"

    /// 무드별 캐릭터 이미지 애셋 이름. Assets.xcassets의 imageset과 일치해야 한다.
    static func characterAsset(for mood: CharacterMood) -> String {
        switch mood {
        case .idle: return "somsom_kkito_idle"
        case .waiting: return "somsom_kkito_waiting"
        case .happy: return "somsom_kkito_happy"
        }
    }
}

/// 캐릭터 무드 (기존 MascotView.Mood와 1:1 대응).
enum CharacterMood {
    case idle      // 평소
    case waiting   // 약 먹을 시간
    case happy     // 인증 완료
}
