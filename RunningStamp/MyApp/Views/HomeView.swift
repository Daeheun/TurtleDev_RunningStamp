import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = RunningPosterViewModel()
    @State private var navigationPath: [RunWorkoutSummary] = []
    @State private var selectedTransitionID: UUID?
    @State private var didStartAutoLoad = false

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
            .navigationDestination(for: RunWorkoutSummary.self) { workout in
                RunDetailView(workout: workout, healthKitManager: viewModel.healthKitManager)
            }
            .task {
                await autoLoadRunsIfNeeded()
            }
        }
    }

    private func autoLoadRunsIfNeeded() async {
        guard !didStartAutoLoad else { return }
        didStartAutoLoad = true
        await viewModel.requestAuthorizationAndLoadRuns()
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
