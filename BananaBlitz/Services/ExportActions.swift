import AppKit
import Foundation

/// The two export actions the app offers from the File menu and from
/// Settings ▸ Data. Each runs a save panel and returns a status line for the
/// caller to show, or nil when the panel was cancelled.
@MainActor
enum ExportActions {
    /// Exports a shell script that reverses every Lock with Immutable File
    /// operation against the current target list.
    static func saveRecoveryScript() -> String? {
        let panel = NSSavePanel()
        panel.title = "Save BananaBlitz Recovery Script"
        panel.nameFieldStringValue = "unbrick.sh"
        panel.message = "Exports a shell script that reverses every Lock with Immutable File operation against the current target list."

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            try UnbrickScriptGenerator.write(to: url, targets: PrivacyTarget.allTargets)
            return "Saved to \(url.path)"
        } catch {
            AppLog.app.error("Unbrick script export failed: \(error.localizedDescription, privacy: .public)")
            return "Save failed: \(error.localizedDescription)"
        }
    }

    /// Exports the cleaning history as JSON or CSV, chosen by file extension.
    static func exportHistory(_ history: [CleaningResult]) -> String? {
        let panel = NSSavePanel()
        panel.title = "Export Cleaning History"
        panel.nameFieldStringValue = "bananablitz-history.json"
        panel.message = "Choose .json or .csv. The format is detected from the file extension."

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let format: HistoryExporter.Format = url.pathExtension.lowercased() == "csv" ? .csv : .json

        do {
            try HistoryExporter.export(history, format: format, to: url)
            return "History saved to \(url.path)"
        } catch {
            AppLog.app.error("History export failed: \(error.localizedDescription, privacy: .public)")
            return "Export failed: \(error.localizedDescription)"
        }
    }
}
