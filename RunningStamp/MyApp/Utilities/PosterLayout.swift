import Combine
import SwiftUI

/// 유료(PRO) 기능: 포스터 섹션 커스텀 배치.
/// iOS 홈 화면처럼 "순서 + 숨김 + 크기"만 저장하고, 실제 위치는 플로우 레이아웃이
/// 자동으로 재배치한다. 기본값(기본 순서·전체 표시·스케일 1)일 때는 기존 디자인과 동일하다.

/// 포스터를 구성하는 편집 가능한 섹션 식별자.
enum PosterSection: String, CaseIterable, Codable, Identifiable {
    case topBar
    case hero
    case stats
    case visual
    case zones
    case timeline
    case signature
    case zoneBar
    case footer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topBar:
            return "브랜드 바"
        case .hero:
            return "러닝 타입·거리"
        case .stats:
            return "스탯 타일"
        case .visual:
            return "러닝 비주얼"
        case .zones:
            return "심박 존 분석"
        case .timeline:
            return "심박 변화"
        case .signature:
            return "러닝 시그니처"
        case .zoneBar:
            return "심박 존 바"
        case .footer:
            return "푸터"
        }
    }

    /// 포스터 형식별 기본 섹션 순서.
    static func sections(for format: PosterFormat) -> [PosterSection] {
        switch format {
        case .feed:
            return [.topBar, .hero, .visual, .zones, .timeline, .signature, .footer]
        case .story:
            return [.topBar, .hero, .stats, .visual, .zoneBar, .footer]
        }
    }

    /// 좌우 패딩을 제외한 캔버스 콘텐츠 폭.
    static func contentWidth(for format: PosterFormat) -> CGFloat {
        format == .feed ? 1_040 : 968
    }

    /// 섹션 기본 크기(캔버스 포인트). 폭이 콘텐츠 폭보다 좁은 섹션은
    /// 플로우 레이아웃이 한 줄에 두 개까지 나란히 배치한다.
    func baseSize(for format: PosterFormat) -> CGSize {
        switch format {
        case .feed:
            switch self {
            case .topBar:
                return CGSize(width: 1_040, height: 34)
            case .hero:
                return CGSize(width: 500, height: 480)
            case .visual:
                return CGSize(width: 520, height: 480)
            case .zones, .timeline:
                return CGSize(width: 512, height: 360)
            case .signature:
                return CGSize(width: 1_040, height: 310)
            case .footer:
                return CGSize(width: 1_040, height: 36)
            default:
                return .zero
            }
        case .story:
            switch self {
            case .topBar:
                return CGSize(width: 968, height: 36)
            case .hero:
                return CGSize(width: 968, height: 400)
            case .stats:
                return CGSize(width: 968, height: 134)
            case .visual:
                return CGSize(width: 968, height: 550)
            case .zoneBar:
                return CGSize(width: 968, height: 220)
            case .footer:
                return CGSize(width: 968, height: 34)
            default:
                return .zero
            }
        }
    }
}

/// 섹션별 편집 상태(숨김 여부 + 핀치 스케일).
struct PosterSectionState: Codable, Equatable {
    var isHidden: Bool = false
    var scale: CGFloat = 1

    static let `default` = PosterSectionState()

    var isDefault: Bool { self == .default }
}

/// 포스터 한 형식(피드 또는 스토리)의 섹션 배치 전체.
struct PosterLayout: Codable, Equatable {
    /// 섹션 표시 순서. 비어 있으면 기본 순서를 사용한다.
    var order: [PosterSection]
    var states: [PosterSection: PosterSectionState]

    init(order: [PosterSection] = [], states: [PosterSection: PosterSectionState] = [:]) {
        self.order = order
        self.states = states
    }

    static let `default` = PosterLayout()

    var isDefault: Bool {
        let orderIsDefault = order.isEmpty
            || order == PosterSection.sections(for: .feed)
            || order == PosterSection.sections(for: .story)
        return orderIsDefault && states.values.allSatisfy(\.isDefault)
    }

    func state(for section: PosterSection) -> PosterSectionState {
        states[section] ?? .default
    }

    /// 저장된 순서를 해당 형식의 섹션으로 정리하고, 누락된 섹션은 기본 순서 위치에 끼워 넣는다.
    func arrangement(for format: PosterFormat) -> [PosterSection] {
        let defaults = PosterSection.sections(for: format)
        guard !order.isEmpty else { return defaults }

        var result = order.filter(defaults.contains)
        for section in defaults where !result.contains(section) {
            guard let defaultIndex = defaults.firstIndex(of: section), defaultIndex > 0,
                  let anchorIndex = result.firstIndex(of: defaults[defaultIndex - 1]) else {
                result.insert(section, at: 0)
                continue
            }
            result.insert(section, at: anchorIndex + 1)
        }
        return result
    }

    func visibleSections(for format: PosterFormat) -> [PosterSection] {
        arrangement(for: format).filter { !state(for: $0).isHidden }
    }

    func hiddenSections(for format: PosterFormat) -> [PosterSection] {
        arrangement(for: format).filter { state(for: $0).isHidden }
    }

    /// 스케일을 캔버스 폭을 넘지 않는 범위로 제한한다.
    func clampedScale(for section: PosterSection, format: PosterFormat) -> CGFloat {
        let base = section.baseSize(for: format)
        guard base.width > 0 else { return 1 }
        let maxScale = PosterSection.contentWidth(for: format) / base.width
        return min(max(state(for: section).scale, 0.5), maxScale)
    }

    mutating func normalizeOrder(for format: PosterFormat) {
        order = arrangement(for: format)
    }

    /// 드래그한 섹션을 대상 섹션 위치로 이동시킨다(나머지는 플로우가 자동 재배치).
    mutating func move(_ section: PosterSection, toPositionOf target: PosterSection, format: PosterFormat) {
        normalizeOrder(for: format)
        guard let from = order.firstIndex(of: section),
              let to = order.firstIndex(of: target),
              from != to else {
            return
        }
        order.remove(at: from)
        guard let targetIndex = order.firstIndex(of: target) else { return }
        order.insert(section, at: from < to ? targetIndex + 1 : targetIndex)
    }

    mutating func setHidden(_ hidden: Bool, for section: PosterSection) {
        var state = self.state(for: section)
        state.isHidden = hidden
        states[section] = state
    }

    mutating func setScale(_ scale: CGFloat, for section: PosterSection, format: PosterFormat) {
        let base = section.baseSize(for: format)
        guard base.width > 0 else { return }
        let maxScale = PosterSection.contentWidth(for: format) / base.width
        var state = self.state(for: section)
        state.scale = min(max(scale, 0.5), maxScale)
        states[section] = state
    }
}

/// 유료(PRO) 기능: 이름을 붙여 저장해 두고 전환할 수 있는 커스텀 배치 프리셋.
struct PosterLayoutPreset: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var layout: PosterLayout

    init(id: UUID = UUID(), name: String, layout: PosterLayout) {
        self.id = id
        self.name = name
        self.layout = layout
    }
}

/// 커스텀 배치 전역 저장소. 피드/스토리 형식별로 UserDefaults에 저장한다.
@MainActor
final class PosterLayoutStore: ObservableObject {
    private static let feedKey = "poster_layout_feed"
    private static let storyKey = "poster_layout_story"
    private static let feedPresetsKey = "poster_layout_presets_feed"
    private static let storyPresetsKey = "poster_layout_presets_story"

    static let maxPresetCount = 8

    @Published var feedLayout: PosterLayout {
        didSet { Self.persist(feedLayout, key: Self.feedKey) }
    }

    @Published var storyLayout: PosterLayout {
        didSet { Self.persist(storyLayout, key: Self.storyKey) }
    }

    @Published var feedPresets: [PosterLayoutPreset] {
        didSet { Self.persistPresets(feedPresets, key: Self.feedPresetsKey) }
    }

    @Published var storyPresets: [PosterLayoutPreset] {
        didSet { Self.persistPresets(storyPresets, key: Self.storyPresetsKey) }
    }

    init() {
        feedLayout = Self.load(key: Self.feedKey)
        storyLayout = Self.load(key: Self.storyKey)
        feedPresets = Self.loadPresets(key: Self.feedPresetsKey)
        storyPresets = Self.loadPresets(key: Self.storyPresetsKey)
    }

    func layout(for format: PosterFormat) -> PosterLayout {
        format == .feed ? feedLayout : storyLayout
    }

    func setLayout(_ layout: PosterLayout, for format: PosterFormat) {
        switch format {
        case .feed:
            feedLayout = layout
        case .story:
            storyLayout = layout
        }
    }

    // MARK: - 프리셋

    func presets(for format: PosterFormat) -> [PosterLayoutPreset] {
        format == .feed ? feedPresets : storyPresets
    }

    /// 현재 배치를 프리셋으로 저장한다. 이름이 비어 있으면 "프리셋 N"으로 자동 명명.
    /// 최대 개수를 넘으면 저장하지 않고 false를 반환한다.
    @discardableResult
    func savePreset(named name: String, for format: PosterFormat) -> Bool {
        var presets = presets(for: format)
        guard presets.count < Self.maxPresetCount else { return false }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? "프리셋 \(presets.count + 1)" : trimmed
        presets.append(PosterLayoutPreset(name: resolvedName, layout: layout(for: format)))
        setPresets(presets, for: format)
        return true
    }

    func applyPreset(_ preset: PosterLayoutPreset, for format: PosterFormat) {
        setLayout(preset.layout, for: format)
    }

    func deletePreset(_ preset: PosterLayoutPreset, for format: PosterFormat) {
        setPresets(presets(for: format).filter { $0.id != preset.id }, for: format)
    }

    private func setPresets(_ presets: [PosterLayoutPreset], for format: PosterFormat) {
        switch format {
        case .feed:
            feedPresets = presets
        case .story:
            storyPresets = presets
        }
    }

    private static func load(key: String) -> PosterLayout {
        guard let data = UserDefaults.standard.data(forKey: key),
              let layout = try? JSONDecoder().decode(PosterLayout.self, from: data) else {
            return .default
        }
        return layout
    }

    private static func persist(_ layout: PosterLayout, key: String) {
        if layout.isDefault {
            UserDefaults.standard.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(layout) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadPresets(key: String) -> [PosterLayoutPreset] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let presets = try? JSONDecoder().decode([PosterLayoutPreset].self, from: data) else {
            return []
        }
        return presets
    }

    private static func persistPresets(_ presets: [PosterLayoutPreset], key: String) {
        if presets.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// 섹션을 순서대로 좌→우, 위→아래로 흘려 배치하는 플로우 레이아웃.
/// 한 줄에 들어가지 못하는 섹션은 다음 줄로 내려가고(iOS 홈 화면식 리플로우),
/// 줄 폭이 남으면 그 줄을 가운데 정렬한다. 섹션 이동·숨김·크기 변경 시
/// 나머지 섹션이 자동으로 재배치된다.
struct PosterFlowLayout: Layout {
    var spacing: CGFloat = 16

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let rows = makeRows(subviews: subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = makeRows(subviews: subviews, width: bounds.width)
        var y = bounds.minY
        for row in rows {
            let rowWidth = row.items.reduce(0) { $0 + $1.size.width } + spacing * CGFloat(max(row.items.count - 1, 0))
            var x = bounds.minX + max((bounds.width - rowWidth) / 2, 0)
            for item in row.items {
                let yOffset = (row.height - item.size.height) / 2
                subviews[item.index].place(at: CGPoint(x: x, y: y + yOffset), proposal: .unspecified)
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var height: CGFloat = 0
    }

    private func makeRows(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var currentWidth: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let neededWidth = current.items.isEmpty ? size.width : currentWidth + spacing + size.width
            if !current.items.isEmpty && neededWidth > width + 0.5 {
                rows.append(current)
                current = Row()
                currentWidth = size.width
            } else {
                currentWidth = neededWidth
            }
            current.items.append((index, size))
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

/// 레이아웃 편집기가 각 섹션의 실제 프레임(캔버스 좌표)을 측정하기 위한 preference.
struct PosterSectionFramePreferenceKey: PreferenceKey {
    static let defaultValue: [PosterSection: Anchor<CGRect>] = [:]

    static func reduce(value: inout [PosterSection: Anchor<CGRect>], nextValue: () -> [PosterSection: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// 포스터 섹션 래핑: 기본 크기로 고정 → 핀치 스케일 적용(레이아웃 크기에도 반영)
    /// → 편집기용 프레임 리포트.
    func posterSection(_ section: PosterSection, layout: PosterLayout, format: PosterFormat) -> some View {
        let base = section.baseSize(for: format)
        let scale = layout.clampedScale(for: section, format: format)
        return self
            .frame(width: base.width, height: base.height, alignment: .topLeading)
            .scaleEffect(scale)
            .frame(width: base.width * scale, height: base.height * scale)
            .anchorPreference(key: PosterSectionFramePreferenceKey.self, value: .bounds) { [section: $0] }
    }
}
