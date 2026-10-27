import SwiftUI

struct DiagnosticsMetricsGrid: View {
    let isPlaying: Bool
    let isObscured: Bool
    let isLowPower: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Engine Diagnostics")
                .font(.headline)
            
            HStack(spacing: 24) {
                MetricColumn(
                    title: "State",
                    value: isPlaying ? "Active" : "Suspended",
                    statusColor: isPlaying ? .green : .orange
                )
                
                Divider()
                    .frame(height: 28)
                
                MetricColumn(
                    title: "Obscuration",
                    value: isObscured ? "Fully Covered" : "Visible",
                    statusColor: isObscured ? .orange : .green
                )
                
                Divider()
                    .frame(height: 28)
                
                MetricColumn(
                    title: "Power Profile",
                    value: isLowPower ? "Eco / Battery" : "Standard",
                    statusColor: isLowPower ? .orange : .blue
                )
                
                Divider()
                    .frame(height: 28)
                
                MetricColumn(
                    title: "Decoder",
                    value: "Apple Silicon HEVC",
                    statusColor: .green
                )
            }
            .padding(.vertical, 8)
        }
    }
}

private struct MetricColumn: View {
    let title: String
    let value: String
    let statusColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            }
        }
    }
}
