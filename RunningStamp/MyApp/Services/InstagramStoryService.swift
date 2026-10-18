import OSLog
import UIKit

@MainActor
enum InstagramStoryService {
    /// Info.plist의 `MetaAppID` 키. Meta for Developers(developers.facebook.com)에서 발급받은 앱 ID를 넣는다.
    static let metaAppIDInfoKey = "MetaAppID"

    /// Info.plist에서 읽은 Meta 앱 ID. 비어 있으면 source_application 없이 공유를 시도하며,
    /// 이 경우 인스타그램 버전에 따라 공유가 거부되거나 스토리에 앱 출처가 표시되지 않는다.
    static var metaAppID: String {
        (Bundle.main.object(forInfoDictionaryKey: metaAppIDInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isConfigured: Bool {
        !metaAppID.isEmpty
    }

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RunStamp", category: "InstagramStoryService")

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

        if !isConfigured {
            logger.warning("MetaAppID가 Info.plist에 없습니다. source_application 없이 스토리 공유를 시도합니다. README의 '인스타그램 스토리 공유 설정'을 참고하세요.")
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
