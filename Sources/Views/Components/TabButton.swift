import SwiftUI

struct TabButton: View {
    let title: String
    let icon: String
    @Binding var selectedTab: String
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            selectedTab = title
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: selectedTab == title ? .semibold : .medium))
                    .frame(width: 16)
                    .foregroundColor(selectedTab == title ? .accentColor : .secondary)
                
                Text(title)
                    .font(.system(size: 12, weight: selectedTab == title ? .semibold : .medium, design: .rounded))
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedTab == title ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .foregroundColor(selectedTab == title ? .accentColor : .primary.opacity(0.85))
        }
        .buttonStyle(PlainButtonStyle())
        .focusable(false)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
