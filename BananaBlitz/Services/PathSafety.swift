import Foundation

/// Shared guardrails for every filesystem operation BananaBlitz performs.
///
/// The target registry is fixed today, but keeping this validation at the
/// service boundary protects future code paths from accidentally operating
/// outside the user's Library or through symlinked parent directories.
enum PathSafety {
    static var defaultLibraryRoot: String {
        (NSHomeDirectory() as NSString).appendingPathComponent("Library")
    }

    static func validateTargetPath(
        _ path: String,
        libraryRoot: String = PathSafety.defaultLibraryRoot,
        rejectExistingSymlink: Bool = true
    ) throws {
        try assertInsideLibrary(path, libraryRoot: libraryRoot)
        try assertNoSymlinkedAncestors(path, libraryRoot: libraryRoot)

        if rejectExistingSymlink, isSymbolicLink(at: path) {
            throw BananaBlitzError.refusedSymlink(path)
        }
    }

    static func assertInsideLibrary(
        _ path: String,
        libraryRoot: String = PathSafety.defaultLibraryRoot
    ) throws {
        let standardised = (path as NSString).standardizingPath
        let standardisedLibrary = (libraryRoot as NSString).standardizingPath

        if standardised == standardisedLibrary { return }
        if standardised.hasPrefix(standardisedLibrary + "/") { return }

        throw BananaBlitzError.refusedOutsideLibrary(path)
    }

    static func isSymbolicLink(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        if let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
           values.isSymbolicLink == true {
            return true
        }

        return (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
    }

    private static func assertNoSymlinkedAncestors(
        _ path: String,
        libraryRoot: String
    ) throws {
        let standardised = (path as NSString).standardizingPath
        let standardisedLibrary = (libraryRoot as NSString).standardizingPath
        let libraryComponents = (standardisedLibrary as NSString).pathComponents
        let pathComponents = (standardised as NSString).pathComponents

        guard pathComponents.count > libraryComponents.count else { return }

        var current = URL(fileURLWithPath: standardisedLibrary, isDirectory: true)
        for component in pathComponents.dropFirst(libraryComponents.count).dropLast() {
            current.appendPathComponent(component, isDirectory: true)
            if isSymbolicLink(at: current.path) {
                throw BananaBlitzError.refusedSymlink(current.path)
            }
        }
    }
}
