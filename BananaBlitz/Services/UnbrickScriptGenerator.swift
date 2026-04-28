import Foundation

/// Generates the `unbrick.sh` recovery script directly from the canonical
/// `PrivacyTarget.allTargets` registry, so the in-app target list and the
/// recovery script can never drift out of sync.
enum UnbrickScriptGenerator {

    /// Produce the script body for the supplied targets.
    static func script(for targets: [PrivacyTarget] = PrivacyTarget.allTargets) -> String {
        let dirTargets = targets.filter { !$0.isSpecificFile }
        let fileTargets = targets.filter { $0.isSpecificFile }

        var lines: [String] = []
        lines.append("#!/bin/bash")
        lines.append("")
        lines.append("# BananaBlitz Unbrick Script")
        lines.append("# Auto-generated from PrivacyTarget.allTargets — do not edit by hand.")
        lines.append("# Reverses the 'Lock with Immutable File' strategy: removes the immutable")
        lines.append("# flag, deletes the lock file, and recreates the directory.")
        lines.append("")
        lines.append("set -u")
        lines.append("")
        lines.append("EXIT_CODE=0")
        lines.append("")
        lines.append("echo \"Reversing BananaBlitz 'replaceWithFile' locks...\"")
        lines.append("")

        lines.append("DIR_TARGETS=(")
        for target in dirTargets {
            lines.append("    \(quote(target.path))")
        }
        lines.append(")")
        lines.append("")

        lines.append("FILE_TARGETS=(")
        for target in fileTargets {
            lines.append("    \(quote(target.path))")
        }
        lines.append(")")
        lines.append("")

        lines.append("for target in \"${DIR_TARGETS[@]}\"; do")
        lines.append("    if [ -e \"$target\" ] && [ ! -d \"$target\" ]; then")
        lines.append("        echo \"Unlocking and restoring directory: $target\"")
        lines.append("        chflags nouchg \"$target\" 2>/dev/null || EXIT_CODE=1")
        lines.append("        rm -f \"$target\" || EXIT_CODE=1")
        lines.append("        mkdir -p \"$target\" || EXIT_CODE=1")
        lines.append("    fi")
        lines.append("done")
        lines.append("")

        lines.append("for target in \"${FILE_TARGETS[@]}\"; do")
        lines.append("    if [ -e \"$target\" ]; then")
        lines.append("        echo \"Unlocking and removing file: $target\"")
        lines.append("        chflags nouchg \"$target\" 2>/dev/null || EXIT_CODE=1")
        lines.append("        rm -f \"$target\" || EXIT_CODE=1")
        lines.append("    fi")
        lines.append("done")
        lines.append("")

        lines.append("echo \"Restarting UI services to restore the menu bar...\"")
        lines.append("killall ControlCenter SystemUIServer Dock 2>/dev/null || true")
        lines.append("")

        lines.append("if [ \"$EXIT_CODE\" -ne 0 ]; then")
        lines.append("    echo \"Done with errors. Review the output above; some paths may still be locked.\"")
        lines.append("else")
        lines.append("    echo \"Done! The menu bar should reappear momentarily. If not, please log out or restart your Mac.\"")
        lines.append("fi")
        lines.append("")
        lines.append("exit $EXIT_CODE")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// Write the script to `url` with `0o755` permissions so it's runnable.
    static func write(to url: URL, targets: [PrivacyTarget] = PrivacyTarget.allTargets) throws {
        let body = script(for: targets)
        try body.data(using: .utf8)?.write(to: url, options: .atomic)
        // Make it executable.
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    // MARK: - Helpers

    /// Wrap a path in double quotes after rewriting a leading `~/` to
    /// `$HOME/` — `~` expansion does *not* happen inside double quotes,
    /// but `$HOME` does. Then escape any embedded `"` or `\`.
    private static func quote(_ path: String) -> String {
        var rewritten = path
        if rewritten.hasPrefix("~/") {
            rewritten = "$HOME/" + String(rewritten.dropFirst(2))
        } else if rewritten == "~" {
            rewritten = "$HOME"
        }
        let escaped = rewritten
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
