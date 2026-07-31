import SwiftUI

struct IndoorEffortMiniView: View {
    let title: String
    let dominantZoneText: String?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("INDOOR")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .tracking(0.8)

            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(RunStampColors.primaryText.opacity(0.82))
                .lineLimit(2)
                .minimumScaleFactor(0.58)
                .frame(height: 20, alignment: .topLeading)

            MiniEffortWaveform(title: title, accent: accent)
                .frame(height: 20)

            if let dominantZoneText {
                Text(dominantZoneText)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(RunStampColors.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 94, height: 66, alignment: .leading)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.10), RunStampColors.surface.opacity(0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(RunStampColors.cardStroke.opacity(0.38), lineWidth: 1))
        .shadow(color: accent.opacity(0.08), radius: 5)
    }
}

struct EffortMiniFallbackView: View {
    let title: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EFFORT")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .tracking(0.8)
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(RunStampColors.primaryText.opacity(0.78))
                .lineLimit(2)
                .minimumScaleFactor(0.58)
            MiniEffortWaveform(title: title, accent: accent)
                .frame(height: 20)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(width: 94, height: 66, alignment: .leading)
        .background(RunStampColors.surface.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(RunStampColors.cardStroke.opacity(0.38), lineWidth: 1))
    }
}

private struct MiniEffortWaveform: View {
    let title: String
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let rect = proxy.frame(in: .local)
            let values = waveformValues(for: title)

            ZStack(alignment: .leading) {
                waveformPath(values: values, in: rect)
                    .stroke(accent.opacity(0.18), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .blur(radius: 1.5)

                waveformPath(values: values, in: rect)
                    .stroke(
                        LinearGradient(
                            colors: waveformColors(for: title, accent: accent),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: accent.opacity(0.38), radius: 3)

            }
        }
    }

    private func waveformPath(values: [CGFloat], in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        for index in values.indices {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = rect.maxY - rect.height * values[index]
            let point = CGPoint(x: x, y: y)
            if index == values.startIndex {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func waveformValues(for title: String) -> [CGFloat] {
        switch title {
        case "CONTROLLED BASE", "RECOVERY FLOW":
            return [0.32, 0.42, 0.38, 0.48, 0.43, 0.50, 0.45]
        case "TEMPO ENGINE", "STEADY BUILDER":
            return [0.28, 0.45, 0.58, 0.66, 0.58, 0.72, 0.64]
        case "REDLINE PUSH":
            return [0.34, 0.66, 0.78, 0.88, 0.82, 0.92, 0.86]
        case "PROGRESSIVE BURN":
            return [0.22, 0.34, 0.45, 0.56, 0.68, 0.76, 0.88]
        default:
            return [0.30, 0.54, 0.38, 0.70, 0.46, 0.62, 0.40]
        }
    }

    private func waveformColors(for title: String, accent: Color) -> [Color] {
        switch title {
        case "REDLINE PUSH":
            return [.orange, .red, accent]
        case "TEMPO ENGINE":
            return [.purple, .orange, accent]
        case "CONTROLLED BASE", "RECOVERY FLOW":
            return [.mint, .green, accent]
        case "PROGRESSIVE BURN":
            return [.yellow, .orange, .pink]
        default:
            return [.blue, accent, .purple]
        }
    }
}

#Preview("CONTROLLED BASE") {
    IndoorEffortMiniView(title: "CONTROLLED BASE", dominantZoneText: "Z2 71%", accent: .green)
        .padding()
        .background(Color(red: 0.02, green: 0.02, blue: 0.08))
}

#Preview("TEMPO ENGINE") {
    IndoorEffortMiniView(title: "TEMPO ENGINE", dominantZoneText: "Z3-Z4 62%", accent: .orange)
        .padding()
        .background(Color(red: 0.02, green: 0.02, blue: 0.08))
}

#Preview("REDLINE PUSH") {
    IndoorEffortMiniView(title: "REDLINE PUSH", dominantZoneText: "Z4-Z5 64%", accent: .red)
        .padding()
        .background(Color(red: 0.02, green: 0.02, blue: 0.08))
}

#Preview("MIXED MILES") {
    IndoorEffortMiniView(title: "MIXED MILES", dominantZoneText: nil, accent: .gray)
        .padding()
        .background(Color(red: 0.02, green: 0.02, blue: 0.08))
}
