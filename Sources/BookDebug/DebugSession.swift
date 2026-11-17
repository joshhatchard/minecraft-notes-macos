import AppKit
import BookUI
import Foundation
import notify

/// Debug launch arguments. All are off unless passed on the command line.
///
/// - `--library <folder>`: use this library folder (and throwaway preferences)
///   instead of ~/Documents/Book and Quill.
/// - `--scenario <file.json>`: play a scenario, write snapshots, then quit.
/// - `--snapshot-dir <folder>`: where scenario snapshots and the log go.
/// - `--snapshot-to <file.png>`: photograph the window once after launch, then quit.
/// - `--listen-for-snapshots <folder>`: keep running; every
///   `notifyutil -p com.bookandquill.debug.snapshot` writes a PNG there.
public struct DebugLaunchOptions: Equatable, Sendable {
    public var libraryRoot: URL?
    public var scenario: URL?
    public var snapshotFolder: URL?
    public var snapshotFile: URL?
    public var listenFolder: URL?

    public init(arguments: [String]) {
        func value(after flag: String) -> URL? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return URL(filePath: (arguments[index + 1] as NSString).expandingTildeInPath)
        }
        libraryRoot = value(after: "--library")
        scenario = value(after: "--scenario")
        snapshotFolder = value(after: "--snapshot-dir")
        snapshotFile = value(after: "--snapshot-to")
        listenFolder = value(after: "--listen-for-snapshots")
    }

    /// Whether any debug facility was requested.
    public var isActive: Bool {
        libraryRoot != nil || scenario != nil || snapshotFile != nil || listenFolder != nil
    }

    /// Whether the UI must record where its clickable parts are.
    var needsTargets: Bool { scenario != nil }
}

/// Starts the requested debug facilities once the window is up.
@MainActor
public final class DebugSession {
    /// Name of the Darwin notification that asks a running app for a snapshot.
    public static let snapshotNotification = "com.bookandquill.debug.snapshot"

    public let options: DebugLaunchOptions
    /// Installed in the view tree only when a scenario runs.
    public let targets: UITargetRegistry?
    private var notifyToken: Int32 = 0

    public init(options: DebugLaunchOptions) {
        self.options = options
        targets = options.needsTargets ? UITargetRegistry() : nil
    }

    /// Call from `applicationDidFinishLaunching`.
    public func start(app: AppModel, libraryRoot: URL) {
        if let listenFolder = options.listenFolder {
            listen(writingTo: listenFolder)
        }
        if let file = options.snapshotFile {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                do {
                    guard let window = WindowSnapshotter.mainWindow else { throw SnapshotError.noWindow }
                    try WindowSnapshotter.writePNG(of: window, to: file)
                } catch {
                    FileHandle.standardError.write(Data("snapshot failed: \(error)\n".utf8))
                }
                if options.scenario == nil, options.listenFolder == nil { NSApp.terminate(nil) }
            }
        }
        if let scenarioURL = options.scenario, let targets {
            let output = options.snapshotFolder ?? URL(filePath: FileManager.default.currentDirectoryPath).appending(path: "snapshots")
            Task { await runScenario(at: scenarioURL, app: app, targets: targets, libraryRoot: libraryRoot, output: output) }
        }
    }

    private func runScenario(at url: URL, app: AppModel, targets: UITargetRegistry, libraryRoot: URL, output: URL) async {
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let log = DebugLog(file: output.appending(path: "log.txt"))
        let failure: String?
        do {
            let scenario = try Scenario.load(from: url)
            failure = await ScenarioRunner(app: app, targets: targets, libraryRoot: libraryRoot, output: output, log: log)
                .run(scenario)
        } catch {
            failure = "could not read \(url.lastPathComponent): \(error)"
            log.write(failure ?? "")
        }
        // The result file is how `make snapshot` learns the outcome, since
        // `open -W` does not report the app's exit status.
        let result = failure.map { "FAIL \($0)\n" } ?? "PASS\n"
        try? Data(result.utf8).write(to: output.appending(path: "result.txt"))
        NSApp.terminate(nil)
    }

    private func listen(writingTo folder: URL) {
        notify_register_dispatch(Self.snapshotNotification, &notifyToken, .main) { _ in
            MainActor.assumeIsolated {
                guard let window = WindowSnapshotter.mainWindow else { return }
                let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                try? WindowSnapshotter.writePNG(of: window, to: folder.appending(path: "snapshot-\(stamp).png"))
            }
        }
    }
}

/// Appends timestamped lines to a log file and to stderr.
@MainActor
public final class DebugLog {
    private let file: URL
    private let start = Date()

    public init(file: URL) {
        self.file = file
        try? Data().write(to: file)
    }

    public func write(_ line: String) {
        let text = String(format: "[%6.2f] ", Date().timeIntervalSince(start)) + line + "\n"
        FileHandle.standardError.write(Data(text.utf8))
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(Data(text.utf8))
            try? handle.close()
        }
    }
}
