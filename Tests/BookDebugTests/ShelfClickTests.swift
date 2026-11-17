import BookCore
import SwiftUI
import Testing

@testable import BookUI

/// Clicks real shelf views with synthesized mouse events.
///
/// Regression for "I cannot create a book from a shelf": the empty slot was a
/// `Color.clear` with a tap gesture, and SwiftUI does not hit-test clear
/// colours, so clicks on an empty slot never reached the gesture.
@MainActor
@Suite("Clicking shelf slots", .serialized)
struct ShelfClickTests {
    let shelfID = ShelfID(chest: ChestID(name: "Semester 1"), name: "Maths")

    final class Recorder {
        var created: [Int] = []
        var opened: [String] = []
        var newBookRequests = 0
    }

    func actions(_ recorder: Recorder) -> (ShelfActions, ShelfSlotActions) {
        (
            ShelfActions(newBook: { _ in recorder.newBookRequests += 1 }, rename: { _ in }, delete: { _ in }),
            ShelfSlotActions(
                open: { recorder.opened.append($0.title) },
                createBook: { _, slot in recorder.created.append(slot) },
                renameBook: { _ in },
                deleteBook: { _ in },
                drop: { _, _, _ in false }
            )
        )
    }

    func host(books: [BookSummary], recorder: Recorder) -> HostedView {
        let shelf = ShelfSummary(id: shelfID, books: books)
        let (shelfActions, slotActions) = actions(recorder)
        return HostedView {
            ShelfRow(
                shelf: shelf,
                blockCount: ShelfLayout.blockCount(occupied: Set(books.map(\.slot))),
                shelfActions: shelfActions,
                slotActions: slotActions
            )
        }
    }

    /// Control: proves synthesized clicks reach SwiftUI in this harness.
    @Test func harnessClicksReachAPlainButton() {
        let recorder = Recorder()
        let hosted = HostedView {
            Button("Press") { recorder.newBookRequests += 1 }.uiTarget("plain")
        }
        defer { hosted.close() }
        #expect(hosted.click("plain"))
        #expect(recorder.newBookRequests == 1)
    }

    @Test func clickingAnEmptySlotCreatesABookThere() {
        let recorder = Recorder()
        let hosted = host(books: [], recorder: recorder)
        defer { hosted.close() }

        #expect(hosted.click(UITargetID.slot(0, onShelf: "Maths")))
        #expect(hosted.click(UITargetID.slot(4, onShelf: "Maths")))
        #expect(recorder.created == [0, 4])
    }

    @Test func clickingABookOpensIt() {
        let recorder = Recorder()
        let book = BookSummary(
            id: BookID(shelf: shelfID, folderName: "Week 1"),
            title: "Week 1",
            author: "",
            isSigned: false,
            slot: 1
        )
        let hosted = host(books: [book], recorder: recorder)
        defer { hosted.close() }

        #expect(hosted.click(UITargetID.slot(1, onShelf: "Maths")))
        #expect(recorder.opened == ["Week 1"])
        #expect(recorder.created.isEmpty)
    }
}
