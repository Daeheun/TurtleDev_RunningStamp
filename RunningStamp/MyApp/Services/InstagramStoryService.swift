import UIKit

@MainActor
enum InstagramStoryService {
    /// Meta for Developers(developers.facebook.com)에서 발급받은 앱 ID.
    /// 비워두면 source_application 파라미터 없이 공유를 시도한다.
    static let metaAppID = ""

    static var isAvailable: Bool {
        guard let url = storiesURL else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private static var storiesURL: URL? {
        var components = URLComponents(string: "instagram-stories://share")
        if !metaAppID.isEmpty {
            components?.queryItems = [URLQueryItem(name: "source_application", value: metaAppID)]
        }
        return components?.url
    }

    /// 포스터 이미지를 배경 레이어로 담아 인스타그램 스토리 편집 화면을 연다.
    /// 인스타그램이 없거나 열기에 실패하면 completion(false).
    static func shareToStories(backgroundImage: UIImage, completion: @escaping @MainActor (Bool) -> Void) {
        guard isAvailable,
              let url = storiesURL,
              let imageData = backgroundImage.pngData() else {
            completion(false)
            return
        }

        let items: [[String: Any]] = [
            ["com.instagram.sharedSticker.backgroundImage": imageData]
        ]
        let options: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)
        ]
        UIPasteboard.general.setItems(items, options: options)

        UIApplication.shared.open(url, options: [:]) { success in
            Task { @MainActor in
                completion(success)
            }
        }
    }
}
