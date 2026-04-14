import SwiftUI

/// Step 3: Optional APFS Snapshot for safety.
struct SnapshotStepView: View {
    @State private var isCreatingInfo = false
    @State private var snapshotStatus: Status = .idle
    @State private var errorMessage: String? = nil
    
    enum Status {
        case idle
        case creating
        case completed
        case failed
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(statusColor)
            }
            .animation(.spring(), value: snapshotStatus)
            
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("(Optional)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.blue)
                    Text("Safety Backup")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                
                Text("Creating an APFS snapshot allows you to revert your system state if anything goes wrong during cleaning.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            VStack(spacing: 12) {
                if snapshotStatus == .completed {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Snapshot Created Successfully")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Button {
                        createSnapshot()
                    } label: {
                        HStack {
                            if snapshotStatus == .creating {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            }
                            Text(snapshotStatus == .creating ? "Creating..." : "Create Snapshot Now")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(width: 200)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(snapshotStatus == .creating)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.top, 4)
                    }
                }
            }
            
            Spacer()
            
            // Warning Footer
            VStack(spacing: 4) {
                Divider()
                    .padding(.bottom, 12)
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    
                    Text("Using any tool that can modify system data is at your own risk. Creating a snapshot provides a local rollback point and is highly recommended before performing your first blitz.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 10)
        }
    }
    
    private var statusIcon: String {
        switch snapshotStatus {
        case .idle: return "camera.on.rectangle.fill"
        case .creating: return "orbit"
        case .completed: return "checkmark.shield.fill"
        case .failed: return "exclamationmark.shield.fill"
        }
    }
    
    private var statusColor: Color {
        switch snapshotStatus {
        case .idle: return .blue
        case .creating: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    private func createSnapshot() {
        snapshotStatus = .creating
        errorMessage = nil
        
        SnapshotService.shared.createSnapshot { result in
            switch result {
            case .success:
                withAnimation {
                    snapshotStatus = .completed
                }
            case .failure(let error):
                snapshotStatus = .failed
                errorMessage = error
            case .cancelled:
                snapshotStatus = .idle
            }
        }
    }
}
