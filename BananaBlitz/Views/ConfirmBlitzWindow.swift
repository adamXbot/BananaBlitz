import SwiftUI

/// Root of the "Confirm Blitz" window opened from the menu bar popover.
/// Wraps `DryRunSheet` so the preview, warning copy and recovery-script
/// offer are identical to the onboarding confirmation.
struct ConfirmBlitzWindow: View {
    /// `nil` only if macOS restores the window without its value.
    let presentation: DryRunPresentation?

    @EnvironmentObject var scheduler: SchedulerService
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        DryRunSheet(
            reports: presentation?.reports ?? [],
            title: "Confirm Blitz",
            confirmTitle: "Blitz Now",
            confirmRole: .destructive,
            onClose: close,
            onConfirm: {
                scheduler.performManualCleanRecordingOutcome()
                close()
            }
        )
    }

    private func close() {
        if let presentation {
            dismissWindow(id: "confirm-blitz", value: presentation)
        } else {
            dismissWindow(id: "confirm-blitz")
        }
    }
}
