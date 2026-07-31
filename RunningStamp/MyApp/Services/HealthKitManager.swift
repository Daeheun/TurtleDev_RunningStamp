import CoreLocation
import Foundation
import HealthKit

struct RunWorkoutSummary: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distanceInMeters: Double
    let activeCalories: Double?
    let averagePaceSecondsPerKm: Double?
    let averageHeartRate: Double?
    let averageRunningPower: Double?
    let averageCadence: Double?
    let locationName: String
    let isIndoorRunning: Bool
    var routeLocations: [CLLocation]

    init(
        id: UUID,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        distanceInMeters: Double,
        activeCalories: Double?,
        averagePaceSecondsPerKm: Double?,
        averageHeartRate: Double?,
        averageRunningPower: Double?,
        averageCadence: Double?,
        locationName: String = "Running Route",
        isIndoorRunning: Bool = false,
        routeLocations: [CLLocation] = []
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.distanceInMeters = distanceInMeters
        self.activeCalories = activeCalories
        self.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        self.averageHeartRate = averageHeartRate
        self.averageRunningPower = averageRunningPower
        self.averageCadence = averageCadence
        self.locationName = locationName
        self.isIndoorRunning = isIndoorRunning
        self.routeLocations = routeLocations
    }

    static func == (lhs: RunWorkoutSummary, rhs: RunWorkoutSummary) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
final class HealthKitManager {
    enum PermissionState: Equatable {
        case notRequested
        case unavailable
        case authorized
        case denied(String)

        var title: String {
            switch self {
            case .notRequested:
                return "Not Connected"
            case .unavailable:
                return "HealthKit Unavailable"
            case .authorized:
                return "Connected"
            case .denied:
                return "Permission Needed"
            }
        }
    }

    private let healthStore = HKHealthStore()
    private var workoutsByID: [UUID: HKWorkout] = [:]

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> PermissionState {
        guard isHealthDataAvailable else {
            return .unavailable
        }

        guard Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil else {
            return .denied("NSHealthShareUsageDescription is missing from the app Info.plist. Add it to the RunStamp target before requesting Apple Health permission.")
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: healthKitReadTypes())
            return .authorized
        } catch {
            return .denied(error.localizedDescription)
        }
    }

    func fetchRecentRunningWorkouts(limit: Int = 10) async throws -> [RunWorkoutSummary] {
        guard isHealthDataAvailable else {
            throw HealthKitError.healthDataUnavailable
        }

        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: runningPredicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }

            healthStore.execute(query)
        }

        workoutsByID = Dictionary(uniqueKeysWithValues: workouts.map { ($0.uuid, $0) })
        return workouts.map(makeSummary(from:))
    }

    func fetchHeartRateSamples(for summary: RunWorkoutSummary) async throws -> [HeartRateSamplePoint] {
        guard let workout = workoutsByID[summary.id] else {
            throw HealthKitError.workoutUnavailable
        }

        return try await fetchHeartRateSamples(for: workout)
    }

    func summaryWithRoute(for summary: RunWorkoutSummary) async throws -> RunWorkoutSummary {
        guard let workout = workoutsByID[summary.id] else {
            return summary
        }

        let routeLocations = try await fetchRouteLocations(for: workout)
        var updatedSummary = summary
        updatedSummary.routeLocations = routeLocations
        return updatedSummary
    }

    private func healthKitReadTypes() -> Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        let identifiers: [HKQuantityTypeIdentifier] = [
            .distanceWalkingRunning,
            .activeEnergyBurned,
            .heartRate,
            .runningPower,
            .stepCount
        ]

        identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) }.forEach { type in
            types.insert(type)
        }

        return types
    }

    private func makeSummary(from workout: HKWorkout) -> RunWorkoutSummary {
        let distanceMeters = workout.totalDistance?.doubleValue(for: .meter())
            ?? sumStatisticValue(for: .distanceWalkingRunning, in: workout, unit: .meter())
            ?? 0
        let activeCalories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
            ?? sumStatisticValue(for: .activeEnergyBurned, in: workout, unit: .kilocalorie())
        let pace = distanceMeters > 0 ? workout.duration / (distanceMeters / 1_000) : nil
        let stepCount = sumStatisticValue(for: .stepCount, in: workout, unit: .count())
        let averageCadence = stepCount.map { $0 / max(workout.duration / 60, 1) }
        let isIndoorRunning = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool ?? false

        return RunWorkoutSummary(
            id: workout.uuid,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            distanceInMeters: distanceMeters,
            activeCalories: activeCalories,
            averagePaceSecondsPerKm: pace,
            averageHeartRate: averageStatisticValue(for: .heartRate, in: workout, unit: HKUnit.count().unitDivided(by: .minute())),
            averageRunningPower: averageStatisticValue(for: .runningPower, in: workout, unit: .watt()),
            averageCadence: averageCadence,
            locationName: isIndoorRunning ? "Indoor Run" : "Running Route",
            isIndoorRunning: isIndoorRunning
        )
    }

    private func fetchHeartRateSamples(for workout: HKWorkout) async throws -> [HeartRateSamplePoint] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return []
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let datePredicate = HKQuery.predicateForSamples(
            withStart: workout.startDate.addingTimeInterval(-5),
            end: workout.endDate.addingTimeInterval(5),
            options: []
        )
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let linkedWorkoutPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, workoutPredicate])

        let linkedSamples = try await queryHeartRateSamples(
            sampleType: heartRateType,
            predicate: linkedWorkoutPredicate,
            sortDescriptor: sortDescriptor
        )

        if !linkedSamples.isEmpty {
            return linkedSamples
        }

        // Some Apple Watch heart-rate samples are present in the workout time range
        // but are not returned by predicateForObjects(from:). Fall back to the selected
        // workout window so real Health data is still used before sample mode.
        return try await queryHeartRateSamples(
            sampleType: heartRateType,
            predicate: datePredicate,
            sortDescriptor: sortDescriptor
        )
    }

    private func queryHeartRateSamples(
        sampleType: HKQuantityType,
        predicate: NSPredicate,
        sortDescriptor: NSSortDescriptor
    ) async throws -> [HeartRateSamplePoint] {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let points = (samples as? [HKQuantitySample] ?? [])
                    .map { sample in
                        HeartRateSamplePoint(
                            date: sample.startDate,
                            bpm: sample.quantity.doubleValue(for: bpmUnit)
                        )
                    }
                    .filter { $0.bpm.isFinite && $0.bpm > 30 && $0.bpm < 240 }

                continuation.resume(returning: points)
            }

            healthStore.execute(query)
        }
    }

    private func sumStatisticValue(
        for identifier: HKQuantityTypeIdentifier,
        in workout: HKWorkout,
        unit: HKUnit
    ) -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        return workout.statistics(for: quantityType)?.sumQuantity()?.doubleValue(for: unit)
    }

    private func averageStatisticValue(
        for identifier: HKQuantityTypeIdentifier,
        in workout: HKWorkout,
        unit: HKUnit
    ) -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        return workout.statistics(for: quantityType)?.averageQuantity()?.doubleValue(for: unit)
    }

    private func fetchRouteLocations(for workout: HKWorkout) async throws -> [CLLocation] {
        let routes = try await fetchRoutes(for: workout)
        guard !routes.isEmpty else { return [] }

        var locations: [CLLocation] = []
        for route in routes {
            let routeLocations = try await fetchLocations(for: route)
            locations.append(contentsOf: routeLocations)
        }

        return normalizedRouteLocations(locations)
    }

    private func fetchRoutes(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        let linkedPredicate = HKQuery.predicateForObjects(from: workout)
        let linkedRoutes = try await queryRoutes(predicate: linkedPredicate)
        if !linkedRoutes.isEmpty {
            return linkedRoutes
        }

        // Older imported workouts sometimes expose HKWorkoutRoute samples by date
        // but do not resolve through predicateForObjects(from:). Use the workout
        // time window as a fallback before concluding that no route exists.
        let datePredicate = HKQuery.predicateForSamples(
            withStart: workout.startDate.addingTimeInterval(-60),
            end: workout.endDate.addingTimeInterval(60),
            options: []
        )
        return try await queryRoutes(predicate: datePredicate)
    }

    private func queryRoutes(predicate: NSPredicate) async throws -> [HKWorkoutRoute] {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKSeriesType.workoutRoute(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: samples as? [HKWorkoutRoute] ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func fetchLocations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        try await withCheckedThrowingContinuation { continuation in
            var locations: [CLLocation] = []

            let query = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let newLocations {
                    locations.append(contentsOf: newLocations)
                }

                if done {
                    continuation.resume(returning: locations)
                }
            }

            healthStore.execute(query)
        }
    }

    private func normalizedRouteLocations(_ locations: [CLLocation]) -> [CLLocation] {
        var seenKeys = Set<String>()
        return locations
            .filter { CLLocationCoordinate2DIsValid($0.coordinate) }
            .sorted { $0.timestamp < $1.timestamp }
            .filter { location in
                let key = String(format: "%.6f:%.6f:%.0f", location.coordinate.latitude, location.coordinate.longitude, location.timestamp.timeIntervalSince1970)
                guard !seenKeys.contains(key) else { return false }
                seenKeys.insert(key)
                return true
            }
    }
}

enum HealthKitError: LocalizedError {
    case healthDataUnavailable
    case workoutUnavailable

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "HealthKit is not available on this device."
        case .workoutUnavailable:
            return "The selected workout is no longer available. Reload recent runs and try again."
        }
    }
}
