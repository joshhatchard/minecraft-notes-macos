import Foundation
import Testing

@testable import BookDebug

@Suite("Scenario files")
struct ScenarioDecodingTests {
    @Test func decodesEveryStepKind() throws {
        let json = """
            { "name": "all", "window": {"width": 900, "height": 640}, "steps": [
              {"click": "new-chest"},
              {"contextMenu": "slot:Maths:0", "item": "New Book Here…"},
              {"type": "Hello"},
              {"key": "]", "modifiers": ["command"]},
              {"key": "return"},
              {"alertButton": "Delete"},
              {"dragBook": "Week 1", "toShelf": "Physics", "slot": 4},
              {"dragShelf": "Maths", "toChest": "Semester 2"},
              {"resize": {"width": 820, "height": 600}},
              {"wait": 0.5},
              {"snapshot": "home"},
              {"expect": {"route": "book", "pageText": "Hello", "books": {"Maths": ["0:Week 1"]},
                          "file": {"path": "a/b.md", "contains": "Hello"}}}
            ]}
            """
        let scenario = try JSONDecoder().decode(Scenario.self, from: Data(json.utf8))
        #expect(scenario.window == Scenario.Size(width: 900, height: 640))
        #expect(
            scenario.steps == [
                .click("new-chest"),
                .contextMenu(target: "slot:Maths:0", item: "New Book Here…"),
                .type("Hello"),
                .key("]", modifiers: ["command"]),
                .key("return", modifiers: []),
                .alertButton("Delete"),
                .dragBook(title: "Week 1", toShelf: "Physics", slot: 4),
                .dragShelf(name: "Maths", toChest: "Semester 2"),
                .resize(.init(width: 820, height: 600)),
                .wait(seconds: 0.5),
                .snapshot("home"),
                .expect(
                    ScenarioExpectation(
                        route: "book",
                        books: ["Maths": ["0:Week 1"]],
                        pageText: "Hello",
                        file: .init(path: "a/b.md", contains: "Hello")
                    )),
            ])
    }

    @Test func rejectsUnknownSteps() {
        let json = #"{"name": "bad", "steps": [{"teleport": "home"}]}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Scenario.self, from: Data(json.utf8))
        }
    }

    @Test func bundledScenariosAllDecode() throws {
        let folder = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../scenarios").standardized
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(!files.isEmpty)
        for file in files {
            #expect(throws: Never.self, "\(file.lastPathComponent)") { try Scenario.load(from: file) }
        }
    }
}

@Suite("Debug launch options")
struct DebugLaunchOptionsTests {
    @Test func offByDefault() {
        let options = DebugLaunchOptions(arguments: ["BookAndQuill", "-NSDocumentRevisionsDebugMode", "YES"])
        #expect(!options.isActive)
        #expect(options.libraryRoot == nil)
    }

    @Test func readsEveryFlag() {
        let options = DebugLaunchOptions(arguments: [
            "app", "--library", "/tmp/lib", "--scenario", "/tmp/s.json", "--snapshot-dir", "/tmp/out",
            "--snapshot-to", "/tmp/one.png", "--listen-for-snapshots", "/tmp/live",
        ])
        #expect(options.isActive)
        #expect(options.libraryRoot?.path == "/tmp/lib")
        #expect(options.scenario?.path == "/tmp/s.json")
        #expect(options.snapshotFolder?.path == "/tmp/out")
        #expect(options.snapshotFile?.path == "/tmp/one.png")
        #expect(options.listenFolder?.path == "/tmp/live")
    }

    @Test func aFlagWithoutValueIsIgnored() {
        #expect(DebugLaunchOptions(arguments: ["app", "--library"]).libraryRoot == nil)
    }
}
