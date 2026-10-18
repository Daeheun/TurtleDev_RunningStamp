import SwiftUI

struct HomeView: View {
    /// 온보딩에서 연결을 미룬 경우 false. 사용자가 카드의 버튼을 눌러야 권한을 요청한다.
    var autoRequestsHealthAccess = true

    @StateObject private var viewModel = RunningPosterViewModel()
    @ObservedObject private var autoPoster = AutoPosterService.shared
    @ObservedObject private var profile = UserProfileStore.shared
    @State private var navigationPath: [RunWorkoutSummary] = []
    @State private var selectedTransitionID: UUID?
    @State private var didStartAutoLoad = false
    @State private var didReloadForPendingWorkout = false
    @State private var isSettingsPresented = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ZStack {
                    RunStampColors.appBackground
                    RadialGradient(
                        colors: [RunStampColors.electricBlue.opacity(0.10), .clear],
                        center: .topTrailing,
                        startRadius: 30,
                        endRadius: 380
                    )
                    RadialGradient(
                        colors: [RunStampColors.vibrantPurple.opacity(0.08), .clear],
                        center: .bottomLeading,
                        startRadius: 40,
                        endRadius: 420
                    )
                }
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if viewModel.permissionState != .authorized || viewModel.workouts.isEmpty {
                            permissionCard
                        }

                        if viewModel.canShowWorkoutPicker || viewModel.isLoadingRuns {
                            WorkoutPickerView(
                                workouts: viewModel.workouts,
                                isLoading: viewModel.isLoadingRuns,
                                message: viewModel.message,
                                healthKitManager: viewModel.healthKitManager,
                                signatureCache: viewModel.signatureCache,
                                selectedTransitionID: selectedTransitionID,
                                reload: { Task { await viewModel.loadRecentRuns() } },
                                onSelect: startReportTransition
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("RunStamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(RunStampColors.secondaryText)
                    }
                    .accessibilityLabel("설정")
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
            .navigationDestination(for: RunWorkoutSummary.self) { workout in
                RunDetailView(workout: workout, healthKitManager: viewModel.healthKitManager)
            }
            .environment(\.distanceUnit, profile.distanceUnit)
            .task {
                await autoLoadRunsIfNeeded()
            }
            .onChange(of: profile.resolvedMaxHeartRate) { _, maxHeartRate in
                // 설정에서 최대 심박을 바꾸면 리스트의 러닝 타입을 새 기준으로 다시 계산한다.
                viewModel.signatureCache.updateMaxHeartRate(maxHeartRate)
            }
            .onChange(of: autoPoster.pendingWorkoutID) { _, _ in
                openPendingWorkoutIfPossible()
            }
            .onChange(of: viewModel.workouts) { _, _ in
                openPendingWorkoutIfPossible()
            }
        }
    }

    private func autoLoadRunsIfNeeded() async {
        guard !didStartAutoLoad else { return }
        didStartAutoLoad = true
        guard autoRequestsHealthAccess else { return }
        await viewModel.requestAuthorizationAndLoadRuns()

        // HealthKit 연동에 성공하면 러닝 종료 감지 + 포스터 준비 알림을 활성화한다.
        if viewModel.permissionState == .authorized {
            await autoPoster.enableIfNeeded()
        }
        openPendingWorkoutIfPossible()
    }

    /// 알림 탭으로 지정된 러닝이 목록에 있으면 상세로 바로 이동한다.
    /// 아직 목록에 없으면 1회에 한해 새로고침을 시도한다(콜드 스타트 직후 대비).
    private func openPendingWorkoutIfPossible() {
        guard let pendingID = autoPoster.pendingWorkoutID else { return }

        if let workout = viewModel.workouts.first(where: { $0.id == pendingID }) {
            autoPoster.pendingWorkoutID = nil
            didReloadForPendingWorkout = false
            navigationPath = [workout]
        } else if didStartAutoLoad && !viewModel.isLoadingRuns {
            guard !didReloadForPendingWorkout else {
                autoPoster.pendingWorkoutID = nil
                didReloadForPendingWorkout = false
                return
            }
            didReloadForPendingWorkout = true
            Task { await viewModel.loadRecentRuns() }
        }
    }

    private func startReportTransition(_ workout: RunWorkoutSummary) {
        guard selectedTransitionID == nil else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedTransitionID = workout.id
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            navigationPath.append(workout)
            try? await Task.sleep(nanoseconds: 180_000_000)
            selectedTransitionID = nil
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Health")
                        .font(.headline)
                    Text(viewModel.permissionState.title)
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                }

                Spacer()
            }

            Text("Apple Watch 러닝 운동, 심박수, 거리, 활동 칼로리를 읽어 러닝 포스터를 생성합니다.")
                .font(.footnote)
                .foregroundStyle(RunStampColors.secondaryText)

            if let message = viewModel.message, !viewModel.isLoadingRuns {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.58))
            }

            Button {
                Task { await viewModel.requestAuthorizationAndLoadRuns() }
            } label: {
                if viewModel.isBusy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Apple Watch 러닝 데이터 불러오기", systemImage: "applewatch")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isBusy)
        }
        .padding(18)
        .foregroundStyle(RunStampColors.primaryText)
        .background(RunStampColors.elevatedSurface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(RunStampColors.cardStroke.opacity(0.45), lineWidth: 1))
    }

    private var statusColor: Color {
        switch viewModel.permissionState {
        case .authorized:
            return .green
        case .denied, .unavailable:
            return .red
        case .notRequested:
            return .secondary
        }
    }
}
