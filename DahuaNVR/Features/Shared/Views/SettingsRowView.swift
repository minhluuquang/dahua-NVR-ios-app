import SwiftUI

struct SettingsRowView: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    List {
        SettingsRowView(
            title: "Camera",
            description: "Manage cameras and video settings",
            icon: "video.fill",
            color: .blue
        )
        
        SettingsRowView(
            title: "Storage",
            description: "Configure recording and storage",
            icon: "externaldrive.fill",
            color: .orange
        )
        
        SettingsRowView(
            title: "Network",
            description: "Network and connectivity settings",
            icon: "network",
            color: .purple
        )
    }
}