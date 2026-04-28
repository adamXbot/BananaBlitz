import Foundation

/// Export `CleaningResult` history as JSON or CSV.
/// All fields are stable — schema changes here are user-visible.
enum HistoryExporter {

    enum Format {
        case json
        case csv
    }

    enum ExportError: LocalizedError {
        case encodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .encodingFailed(let detail):
                return "Failed to encode history: \(detail)"
            }
        }
    }

    static func export(_ history: [CleaningResult], format: Format, to url: URL) throws {
        let data: Data
        switch format {
        case .json:
            data = try jsonData(for: history)
        case .csv:
            data = try csvData(for: history)
        }
        try data.write(to: url, options: .atomic)
    }

    // MARK: - JSON

    private static func jsonData(for history: [CleaningResult]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(history)
        } catch {
            throw ExportError.encodingFailed(error.localizedDescription)
        }
    }

    // MARK: - CSV

    private static func csvData(for history: [CleaningResult]) throws -> Data {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append("timestamp,target_id,target_name,strategy,success,bytes_reclaimed,error")
        for result in history {
            lines.append([
                formatter.string(from: result.timestamp),
                csvQuote(result.targetID),
                csvQuote(result.targetName),
                result.strategy.rawValue,
                result.success ? "true" : "false",
                String(result.bytesReclaimed),
                csvQuote(result.error ?? "")
            ].joined(separator: ","))
        }
        let body = lines.joined(separator: "\n") + "\n"
        guard let data = body.data(using: .utf8) else {
            throw ExportError.encodingFailed("UTF-8 conversion failed")
        }
        return data
    }

    /// RFC 4180 — wrap fields containing `,`, `"`, `\n`, or `\r` in quotes
    /// and double any embedded quotes.
    private static func csvQuote(_ field: String) -> String {
        let needsQuoting = field.contains(",") || field.contains("\"") ||
                           field.contains("\n") || field.contains("\r")
        guard needsQuoting else { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
