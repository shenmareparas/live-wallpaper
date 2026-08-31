import SwiftUI

struct MiniDiagCard: View {
    let title: String
    let value: String
    let statusColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(value)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

struct DiagnosticsMetricsGrid: View {
    let isPlaying: Bool
    let isObscured: Bool
    let isLowPower: Bool
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DIAGNOSTICS & METRICS")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: columns, spacing: 8) {
                MiniDiagCard(title: "Obscuration", value: isObscured ? "Obscured" : "Visible", statusColor: isObscured ? .orange : .green)
                MiniDiagCard(title: "Power Mode", value: isLowPower ? "Eco Mode" : "Normal", statusColor: isLowPower ? .orange : .blue)
                MiniDiagCard(title: "Target FPS", value: isPlaying ? "60 FPS" : "0 FPS", statusColor: isPlaying ? .green : .secondary)
                MiniDiagCard(title: "Decoder", value: "Hardware HEVC", statusColor: .green)
            }
        }
    }
}
