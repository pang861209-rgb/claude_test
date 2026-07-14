import UIKit

/// 인증 사진을 앱 내부 저장소(Documents/photos)에 JPEG로 저장/로드한다.
/// 사진 라이브러리를 오염시키지 않기 위해 앱 샌드박스에만 보관한다.
enum PhotoStorage {

    /// 긴 변 리사이즈 목표 픽셀 (기획서 §10).
    static let maxDimension: CGFloat = 1280
    /// JPEG 압축 품질.
    static let jpegQuality: CGFloat = 0.7

    private static var photosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 이미지를 리사이즈·압축해 저장하고 Documents 기준 **상대 경로**를 반환한다.
    /// SwiftData에는 이 상대 경로만 저장한다 (앱 재설치/경로 변경 대비).
    @discardableResult
    static func save(_ image: UIImage) -> String? {
        let resized = resize(image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return nil }

        let fileName = "\(UUID().uuidString).jpg"
        let url = photosDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return "photos/\(fileName)"
        } catch {
            return nil
        }
    }

    /// 상대 경로로 저장된 이미지를 로드한다.
    static func load(relativePath: String) -> UIImage? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(relativePath: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }

    /// 긴 변을 maxDimension으로 맞춰 비율 유지 리사이즈. 이미 작으면 원본 반환.
    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // 픽셀 크기를 그대로 제어
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
