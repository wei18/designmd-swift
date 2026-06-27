// Cross-platform fixture loading.
//
// On Linux, `Bundle.urls(forResourcesWithExtension:subdirectory:)` returns
// `[NSURL]` and `url(forResource:withExtension:)` is unreliable with multi-dot
// extensions. Resolving paths from `resourceURL` + FileManager works the same
// on macOS and Linux.

import Foundation

func fixturesDirectory() -> URL {
    Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
}

func fixtureFile(_ name: String) -> URL {
    fixturesDirectory().appendingPathComponent(name)
}

/// All `.md` fixtures, sorted by filename.
func allFixtureMD() -> [URL] {
    let all = (try? FileManager.default.contentsOfDirectory(
        at: fixturesDirectory(), includingPropertiesForKeys: nil)) ?? []
    return all
        .filter { $0.pathExtension == "md" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}
