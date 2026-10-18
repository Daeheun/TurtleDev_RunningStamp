import SwiftUI

/// 최초 실행 온보딩 3장. 권한을 요청하기 전에 포스터 예시로 가치를 먼저 보여준다.
/// 마지막 장에서 "Apple 건강 연결하기"를 누르면 `onFinish(true)`, 나중에를 고르면 `onFinish(false)`.
struct OnboardingView: View {
    let onFinish: (_ connectsHealth: Bool) -> Void

    @State private var page = 0
    private let pageCount = 3

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar

                TabView(selection: $page) {
                    posterPage.tag(0)
                    analysisPage.tag(1)
                    healthPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: page)

                pageDots
                    .padding(.bottom, 18)

                bottomButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 배경 / 공통

    private var background: some View {
        ZStack {
            RunStampColors.appBackground
            RadialGradient(
                colors: [RunStampColors.energyOrange.opacity(0.14), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            RadialGradient(
                colors: [RunStampColors.electricBlue.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Text("RUNSTAMP")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(RunStampColors.secondaryText)
                .kerning(2)
            Spacer()
            if page < pageCount - 1 {
                Button("건너뛰기") {
                    withAnimation { page = pageCount - 1 }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RunStampColors.tertiaryText)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .frame(height: 44)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? RunStampColors.limeGreen : RunStampColors.cardStroke)
                    .frame(width: index == page ? 22 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.22), value: page)
            }
        }
    }

    @ViewBuilder
    private var bottomButtons: some View {
        if page < pageCount - 1 {
            primaryButton(title: "다음") {
                withAnimation { page += 1 }
            }
        } else {
            VStack(spacing: 10) {
                primaryButton(title: "Apple 건강 연결하기", systemImage: "heart.text.square.fill") {
                    onFinish(true)
                }
                Button("나중에 할게요") {
                    onFinish(false)
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RunStampColors.secondaryText)
                .padding(.vertical, 6)
            }
        }
    }

    private func primaryButton(title: String, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .black))
                }
                Text(title)
                    .font(.system(size: 16, weight: .black))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(RunStampColors.appBackground)
            .background(RunStampColors.limeGreen)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func headline(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(RunStampColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RunStampColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 1장: 포스터 예시

    private var posterPage: some View {
        VStack(spacing: 22) {
            headline(
                "러닝이 끝나면\n포스터가 완성됩니다",
                subtitle: "Apple Watch 러닝 기록을 심박 존 분석과 함께 공유용 포스터로 만들어 드립니다."
            )
            .padding(.horizontal, 24)

            GeometryReader { proxy in
                let width = min(proxy.size.width * 0.66, 300)
                let report = HeartRateZoneAnalyzer().sampleReport()
                let stamp = HighlightStamp(target: .firePoster, style: .fire).resolved(for: report)

                ScaledCanvasPreview(canvasSize: ZoneRunPosterView.canvasSize) {
                    ZoneRunPosterView(report: report, highlightStamp: stamp, contentHighlight: nil, layout: .default)
                }
                .frame(width: width, height: width * ZoneRunPosterView.canvasSize.height / ZoneRunPosterView.canvasSize.width)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.45), radius: 28, y: 14)
                .rotationEffect(.degrees(-4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.bottom, 8)
        }
        .padding(.top, 12)
    }

    // MARK: - 2장: 분석·알림·공유

    private var analysisPage: some View {
        VStack(alignment: .leading, spacing: 26) {
            headline(
                "심박 존이 말해주는\n오늘의 러닝 타입",
                subtitle: "존 1~5 체류 시간을 분석해 이지런·템포런·인터벌 같은 러닝 타입을 자동으로 읽어냅니다."
            )

            zoneIllustration

            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "waveform.path.ecg", color: RunStampColors.redlineRed, title: "심박 존 분석", text: "나이 또는 직접 입력한 최대 심박을 기준으로 존을 나눕니다.")
                featureRow(icon: "bell.badge.fill", color: RunStampColors.warmYellow, title: "러닝 종료 알림", text: "Apple Watch 러닝이 동기화되면 포스터가 준비됐다고 알려드립니다.")
                featureRow(icon: "camera.circle.fill", color: RunStampColors.vibrantPurple, title: "인스타 공유", text: "피드 4:5와 스토리 9:16 비율로 바로 공유할 수 있습니다.")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var zoneIllustration: some View {
        let bars: [(CGFloat, Color)] = [
            (0.35, RunStampColors.electricBlue),
            (0.55, RunStampColors.aquaTeal),
            (1.0, RunStampColors.limeGreen),
            (0.72, RunStampColors.energyOrange),
            (0.28, RunStampColors.redlineRed)
        ]

        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(bar.1.opacity(index == 2 ? 1 : 0.55))
                        .frame(height: 88 * bar.0)
                        .frame(maxWidth: .infinity)
                    Text("Z\(index + 1)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(index == 2 ? RunStampColors.primaryText : RunStampColors.tertiaryText)
                }
            }
        }
        .padding(16)
        .background(RunStampColors.elevatedSurface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(RunStampColors.cardStroke.opacity(0.45), lineWidth: 1))
    }

    private func featureRow(icon: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(RunStampColors.primaryText)
                Text(text)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RunStampColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 3장: Apple 건강 연결

    private var healthPage: some View {
        VStack(alignment: .leading, spacing: 26) {
            headline(
                "Apple 건강과\n연결해 주세요",
                subtitle: "다음 화면에서 iOS가 읽기 권한을 물어봅니다. 모든 항목을 허용해야 포스터가 완전하게 만들어집니다."
            )

            VStack(alignment: .leading, spacing: 12) {
                dataRow(icon: "figure.run", text: "러닝 운동 기록 · 거리 · 활동 칼로리")
                dataRow(icon: "heart.fill", text: "심박수 (존 분석과 러닝 타입)")
                dataRow(icon: "map.fill", text: "운동 경로 (포스터의 네온 경로맵)")
                dataRow(icon: "person.text.rectangle", text: "생년월일 (최대 심박 220 − 나이 계산)")
            }
            .padding(18)
            .background(RunStampColors.elevatedSurface.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(RunStampColors.cardStroke.opacity(0.45), lineWidth: 1))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(RunStampColors.aquaTeal)
                Text("분석과 포스터 생성은 모두 iPhone 안에서 처리됩니다. 건강 데이터가 RunStamp 서버로 전송되는 일은 없습니다.")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RunStampColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private func dataRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RunStampColors.limeGreen)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RunStampColors.primaryText.opacity(0.9))
        }
    }
}

#Preview {
    OnboardingView { _ in }
}
