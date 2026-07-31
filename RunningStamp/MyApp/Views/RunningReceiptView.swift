import SwiftUI

struct RunningReceiptView: View {
    let workout: RunWorkoutSummary

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.96, blue: 0.92)

            VStack(spacing: 28) {
                Text("RUNNING RECEIPT")
                    .font(.system(size: 54, weight: .bold, design: .monospaced))
                    .tracking(2)

                dashedRule

                VStack(spacing: 18) {
                    receiptLine("DATE", RunFormatters.cardDate(workout.startDate))
                    receiptLine("LOCATION", workout.locationName.uppercased())
                    receiptLine("DISTANCE", RunFormatters.distanceKm(workout.distanceInMeters))
                    receiptLine("TIME", RunFormatters.duration(workout.duration))
                    receiptLine("PACE", RunFormatters.pace(workout.averagePaceSecondsPerKm))
                    receiptLine("CALORIES", RunFormatters.calories(workout.activeCalories))
                    receiptLine("AVG HEART RATE", RunFormatters.heartRate(workout.averageHeartRate))
                    receiptLine("AVG POWER", RunFormatters.power(workout.averageRunningPower))
                    receiptLine("AVG CADENCE", RunFormatters.cadence(workout.averageCadence))
                }

                dashedRule

                VStack(spacing: 16) {
                    Text("PAYMENT")
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                    receiptLine("DISCIPLINE", "+1")
                    receiptLine("REGRET", "0")
                    receiptLine("MOOD", "BETTER")
                }

                Spacer(minLength: 0)

                dashedRule

                Text("THANK YOU FOR RUNNING")
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .tracking(1.2)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 72)
            .padding(.vertical, 96)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var dashedRule: some View {
        Text(String(repeating: "-", count: 28))
            .font(.system(size: 28, weight: .regular, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func receiptLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 27, weight: .regular, design: .monospaced))
                .foregroundStyle(.black.opacity(0.72))
            Spacer(minLength: 24)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
        }
    }
}

