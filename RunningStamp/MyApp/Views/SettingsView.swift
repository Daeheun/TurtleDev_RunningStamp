import SwiftUI
import UIKit
import UserNotifications

/// 설정 화면: 심박 존 기준(최대 심박), 러닝 종료 알림, 거리 단위, 데이터 안내.
struct SettingsView: View {
    @ObservedObject private var profile = UserProfileStore.shared
    @ObservedObject private var autoPoster = AutoPosterService.shared
    @ObservedObject private var preferences = AppPreferences.shared
    @Environment(\.dismiss) private var dismiss

    @State private var usesManualMaxHeartRate: Bool
    @State private var manualMaxHeartRateDraft: Int
    @State private var isNotificationDenied = false
    @State private var isUpdatingNotification = false

    init() {
        let profile = UserProfileStore.shared
        _usesManualMaxHeartRate = State(initialValue: profile.manualMaxHeartRate != nil)
        _manualMaxHeartRateDraft = State(initialValue: profile.manualMaxHeartRate ?? Int(profile.resolvedMaxHeartRate))
    }

    var body: some View {
        NavigationStack {
            Form {
                heartRateSection
                notificationSection
                unitSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(RunStampColors.appBackground.ignoresSafeArea())
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                        .fontWeight(.black)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(RunStampColors.limeGreen)
        .task {
            await refreshNotificationStatus()
        }
        .onChange(of: profile.distanceUnit) { _, _ in
            Analytics.shared.track(.settingChanged(key: "distance_unit"))
        }
        .onChange(of: usesManualMaxHeartRate) { _, _ in
            Analytics.shared.track(.settingChanged(key: "max_heart_rate_manual"))
        }
        .onChange(of: preferences.isAnalyticsEnabled) { _, isOn in
            // 끄는 순간은 기록되지 않고, 다시 켠 사실만 남는다.
            if isOn { Analytics.shared.track(.settingChanged(key: "analytics_enabled")) }
        }
    }

    // MARK: - 심박 존 기준

    private var heartRateSection: some View {
        Section {
            LabeledContent("적용 중인 최대 심박") {
                Text("\(Int(profile.resolvedMaxHeartRate)) BPM")
                    .font(.system(.body, design: .rounded, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(RunStampColors.limeGreen)
            }

            Toggle("최대 심박 직접 입력", isOn: $usesManualMaxHeartRate)
                .onChange(of: usesManualMaxHeartRate) { _, isOn in
                    if isOn {
                        manualMaxHeartRateDraft = clampedDraft(manualMaxHeartRateDraft)
                        profile.manualMaxHeartRate = manualMaxHeartRateDraft
                    } else {
                        profile.manualMaxHeartRate = nil
                    }
                }

            if usesManualMaxHeartRate {
                Stepper(value: $manualMaxHeartRateDraft, in: UserProfileStore.manualMaxHeartRateRange, step: 1) {
                    LabeledContent("최대 심박") {
                        Text("\(manualMaxHeartRateDraft) BPM")
                            .monospacedDigit()
                            .fontWeight(.bold)
                    }
                }
                .onChange(of: manualMaxHeartRateDraft) { _, value in
                    profile.manualMaxHeartRate = clampedDraft(value)
                }
            }
        } header: {
            Text("심박 존 기준")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(maxHeartRateSourceDescription)
                Text("존 1~5는 최대 심박의 50 · 60 · 70 · 80 · 90% 경계로 나눕니다. 값을 바꾸면 모든 러닝의 존 분석과 러닝 타입이 다시 계산됩니다.")
            }
        }
    }

    private var maxHeartRateSourceDescription: String {
        switch profile.maxHeartRateSource {
        case .manual:
            if let age = profile.healthAge, let estimated = profile.ageEstimatedMaxHeartRate {
                return "직접 입력한 값을 사용합니다. 끄면 Apple Health 생년월일 기준(\(age)세 → \(estimated) BPM)으로 돌아갑니다."
            }
            return "직접 입력한 값을 사용합니다."
        case .healthAge(let age):
            return "Apple Health 생년월일 기준 \(age)세 · 220 − 나이 공식으로 계산했습니다. 실제 최대 심박을 알고 있다면 직접 입력이 더 정확합니다."
        case .fallback:
            return "Apple Health에서 생년월일을 읽지 못해 기본값 \(UserProfileStore.fallbackMaxHeartRate) BPM을 사용합니다. 건강 앱 > 프로필에 생년월일을 입력하거나 여기서 직접 입력해 주세요."
        }
    }

    private func clampedDraft(_ value: Int) -> Int {
        min(max(value, UserProfileStore.manualMaxHeartRateRange.lowerBound), UserProfileStore.manualMaxHeartRateRange.upperBound)
    }

    // MARK: - 알림

    private var notificationSection: some View {
        Section {
            Toggle(isOn: notificationBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("러닝 종료 후 포스터 알림")
                    Text("Apple Watch 러닝이 동기화되면 포스터가 준비됐다고 알려드립니다.")
                        .font(.footnote)
                        .foregroundStyle(RunStampColors.secondaryText)
                }
            }
            .disabled(isUpdatingNotification)

            if isNotificationDenied {
                Button {
                    openSystemSettings()
                } label: {
                    Label("iOS 설정에서 알림 허용하기", systemImage: "bell.slash")
                }
            }
        } header: {
            Text("알림")
        } footer: {
            if isNotificationDenied {
                Text("iOS 설정에서 RunStamp 알림이 꺼져 있어 포스터 알림을 받을 수 없습니다.")
            } else {
                Text("알림은 러닝 1회당 1번만 발송됩니다.")
            }
        }
    }

    private var notificationBinding: Binding<Bool> {
        Binding(
            get: { autoPoster.isEnabled },
            set: { isOn in
                isUpdatingNotification = true
                Task {
                    await autoPoster.setEnabled(isOn)
                    await refreshNotificationStatus()
                    isUpdatingNotification = false
                    Analytics.shared.track(.settingChanged(key: isOn ? "run_notification_on" : "run_notification_off"))
                }
            }
        )
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isNotificationDenied = settings.authorizationStatus == .denied
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - 단위

    private var unitSection: some View {
        Section {
            Picker("거리 단위", selection: $profile.distanceUnit) {
                ForEach(DistanceUnit.allCases) { unit in
                    Text("\(unit.displayName) (\(unit.lowercaseSymbol))").tag(unit)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("단위")
        } footer: {
            Text("리스트, 월 요약, 포스터의 거리·페이스·속도에 모두 적용됩니다.")
        }
    }

    // MARK: - 데이터

    private var dataSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                dataRow(icon: "heart.text.square.fill", text: "Apple Health에 저장된 러닝 운동, 심박수, 거리, 활동 칼로리, 경로, 생년월일을 읽기만 합니다.")
                dataRow(icon: "iphone", text: "분석과 포스터 생성은 모두 이 기기 안에서 처리되며 RunStamp 서버로 전송되는 데이터는 없습니다.")
                dataRow(icon: "square.and.arrow.up", text: "포스터 이미지는 직접 저장하거나 공유할 때만 기기 밖으로 나갑니다.")
            }
            .padding(.vertical, 4)

            Button {
                openHealthApp()
            } label: {
                Label("건강 앱에서 권한 관리", systemImage: "arrow.up.forward.app")
            }

            Toggle(isOn: $preferences.isAnalyticsEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("익명 사용 통계 보내기")
                    Text("기능 사용 횟수만 집계합니다. 거리·심박·위치 같은 건강 데이터는 포함되지 않습니다.")
                        .font(.footnote)
                        .foregroundStyle(RunStampColors.secondaryText)
                }
            }
        } header: {
            Text("데이터")
        } footer: {
            Text("건강 앱 > 공유 > 앱 및 서비스 > RunStamp에서 읽기 권한을 변경할 수 있습니다.")
        }
    }

    private func dataRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RunStampColors.aquaTeal)
                .frame(width: 20)
            Text(text)
                .font(.footnote)
                .foregroundStyle(RunStampColors.secondaryText)
        }
    }

    private func openHealthApp() {
        guard let url = URL(string: "x-apple-health://") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - 정보

    private var aboutSection: some View {
        Section {
            LabeledContent("버전", value: appVersionText)
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
