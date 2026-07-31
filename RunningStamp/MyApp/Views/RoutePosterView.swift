import CoreLocation
import MapKit
import SwiftUI

struct RoutePosterView: View {
    let workout: RunWorkoutSummary

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.04, blue: 0.045)

            VStack(alignment: .leading, spacing: 0) {
                Text("TODAY’S TRACE")
                    .font(.system(size: 58, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .tracking(1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(workout.locationName.uppercased())
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.top, 12)

                RouteDrawingView(locations: workout.routeLocations)
                    .frame(maxWidth: .infinity)
                    .frame(height: 980)
                    .padding(.vertical, 58)

                if workout.routeLocations.isEmpty {
                    Text("NO ROUTE DATA AVAILABLE")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 40)
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    metricBlock("DISTANCE", RunFormatters.distanceKm(workout.distanceInMeters))
                    Spacer()
                    metricBlock("PACE", RunFormatters.pace(workout.averagePaceSecondsPerKm))
                }

                HStack(alignment: .bottom) {
                    metricBlock("DATE", RunFormatters.cardDate(workout.startDate))
                    Spacer()
                    metricBlock("TIME", RunFormatters.duration(workout.duration))
                }
                .padding(.top, 34)
            }
            .padding(72)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metricBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 34, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
    }
}

private struct RouteDrawingView: View {
    let locations: [CLLocation]

    var body: some View {
        GeometryReader { proxy in
            let rect = proxy.frame(in: .local)
            let points = routePoints(in: rect)

            ZStack {
                routePath(points: points)
                    .stroke(
                        LinearGradient(
                            colors: [.white, Color(red: 0.3, green: 0.95, blue: 0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color(red: 0.3, green: 0.95, blue: 0.78).opacity(0.35), radius: 20)

                if let start = points.first {
                    marker(at: start, color: Color(red: 0.3, green: 0.95, blue: 0.78))
                }

                if let end = points.last {
                    marker(at: end, color: .white)
                }
            }
        }
    }

    private func marker(at point: CGPoint, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 26, height: 26)
            .overlay(Circle().stroke(.black.opacity(0.7), lineWidth: 5))
            .position(point)
    }

    private func routePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        return path
    }

    private func routePoints(in rect: CGRect) -> [CGPoint] {
        if locations.count >= 2 {
            return normalizedPoints(for: locations, in: rect)
        }

        return placeholderPoints(in: rect)
    }

    private func normalizedPoints(for locations: [CLLocation], in rect: CGRect) -> [CGPoint] {
        let coordinates = locations.map(\.coordinate)
        guard let minLatitude = coordinates.map(\.latitude).min(),
              let maxLatitude = coordinates.map(\.latitude).max(),
              let minLongitude = coordinates.map(\.longitude).min(),
              let maxLongitude = coordinates.map(\.longitude).max() else {
            return placeholderPoints(in: rect)
        }

        let latitudeSpan = max(maxLatitude - minLatitude, 0.000_001)
        let longitudeSpan = max(maxLongitude - minLongitude, 0.000_001)
        let drawingRect = rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.1)

        return coordinates.map { coordinate in
            let x = drawingRect.minX + ((coordinate.longitude - minLongitude) / longitudeSpan) * drawingRect.width
            let y = drawingRect.maxY - ((coordinate.latitude - minLatitude) / latitudeSpan) * drawingRect.height
            return CGPoint(x: x, y: y)
        }
    }

    private func placeholderPoints(in rect: CGRect) -> [CGPoint] {
        let drawingRect = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.14)
        return [
            CGPoint(x: drawingRect.minX + drawingRect.width * 0.14, y: drawingRect.maxY - drawingRect.height * 0.10),
            CGPoint(x: drawingRect.minX + drawingRect.width * 0.22, y: drawingRect.minY + drawingRect.height * 0.62),
            CGPoint(x: drawingRect.minX + drawingRect.width * 0.58, y: drawingRect.minY + drawingRect.height * 0.72),
            CGPoint(x: drawingRect.minX + drawingRect.width * 0.44, y: drawingRect.minY + drawingRect.height * 0.30),
            CGPoint(x: drawingRect.minX + drawingRect.width * 0.76, y: drawingRect.minY + drawingRect.height * 0.18),
            CGPoint(x: drawingRect.minX + drawingRect.width * 0.88, y: drawingRect.minY + drawingRect.height * 0.50)
        ]
    }
}

