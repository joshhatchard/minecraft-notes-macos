import BookCore
import Foundation
import Testing

@Suite("Book model")
struct BookTests {
    let fitter = PageFitter()
    let start = Date(timeIntervalSince1970: 1_000)
    let later = Date(timeIntervalSince1970: 2_000)

    private func makeBook() -> Book {
        Book(title: "Week 1", createdAt: start)
    }

    @Test func newBookHasOneBlankPage() {
        let book = makeBook()
        #expect(book.pages == [Page()])
        #expect(!book.isSigned)
        #expect(book.updatedAt == start)
    }

    @Test func settingTextUpdatesPageAndTimestamp() throws {
        var book = makeBook()
        try book.setText("Notes", onPage: 0, fitter: fitter, now: later)
        #expect(book.pages[0].text == "Notes")
        #expect(book.updatedAt == later)
    }

    @Test func overflowingTextIsRejected() {
        var book = makeBook()
        #expect(throws: BookError.pageOverflow(.tooManyCharacters(257))) {
            try book.setText(String(repeating: "i", count: 257), onPage: 0, fitter: fitter, now: later)
        }
        #expect(book.pages[0].text.isEmpty)
    }

    @Test func invalidPageIndexIsRejected() {
        var book = makeBook()
        #expect(throws: BookError.pageIndexOutOfRange(3)) {
            try book.setText("x", onPage: 3, fitter: fitter, now: later)
        }
    }

    @Test func pagesStopAtOneHundred() throws {
        var book = makeBook()
        for _ in 1..<BookLimits.maxPages {
            try book.appendPage(now: later)
        }
        #expect(book.pages.count == 100)
        #expect(!book.canAddPage)
        #expect(throws: BookError.pageLimitReached) { try book.appendPage(now: later) }
    }

    @Test func signingLocksTheBook() throws {
        var book = makeBook()
        try book.setText("Draft", onPage: 0, fitter: fitter, now: later)
        try book.sign(title: "  Final Notes ", author: "Josh", now: later)
        #expect(book.isSigned)
        #expect(book.title == "Final Notes")
        #expect(book.author == "Josh")
        #expect(!book.canAddPage)
        #expect(throws: BookError.signed) { try book.setText("Edit", onPage: 0, fitter: fitter, now: later) }
        #expect(throws: BookError.signed) { try book.appendPage(now: later) }
        #expect(throws: BookError.signed) { try book.sign(title: "Again", author: "Josh", now: later) }
        #expect(book.pages[0].text == "Draft")
    }

    @Test func signingNeedsTitleAndAuthor() {
        var book = makeBook()
        #expect(throws: BookError.invalidTitle(.empty)) { try book.sign(title: "  ", author: "Josh", now: later) }
        #expect(throws: BookError.invalidAuthor(.empty)) { try book.sign(title: "Title", author: "", now: later) }
        #expect(throws: BookError.invalidTitle(.tooLong(max: BookLimits.maxTitleLength))) {
            try book.sign(title: String(repeating: "t", count: 33), author: "Josh", now: later)
        }
        #expect(!book.isSigned)
    }

    @Test func signedBooksCanStillBeRenamed() throws {
        var book = makeBook()
        try book.sign(title: "Title", author: "Josh", now: later)
        try book.rename(to: "Filed Under", now: later)
        #expect(book.title == "Filed Under")
    }

    @Test func loadedOverfullContentIsKept() {
        let overfull = String(repeating: "i", count: 400)
        let book = Book(title: "Imported", createdAt: start, pages: [Page(text: overfull)])
        #expect(book.pages[0].text == overfull)
    }
}

@Suite("Names and shelf slots")
struct NameAndShelfTests {
    @Test func namesAreTrimmedAndValidated() {
        #expect(NameRules.validate("  Maths  ", maxLength: 10) == .success("Maths"))
        #expect(NameRules.validate("   ", maxLength: 10) == .failure(.empty))
        #expect(NameRules.validate("abcdefghijk", maxLength: 10) == .failure(.tooLong(max: 10)))
        #expect(NameRules.validate("a\u{0007}b", maxLength: 10) == .failure(.containsControlCharacters))
    }

    @Test func firstFreeSlotFillsGaps() {
        #expect(ShelfLayout.firstFreeSlot(occupied: []) == 0)
        #expect(ShelfLayout.firstFreeSlot(occupied: [0, 1, 3]) == 2)
    }

    @Test func shelvesGrowByWholeBlocksAndKeepAFreeSlot() {
        #expect(ShelfLayout.blockCount(occupied: []) == 1)
        #expect(ShelfLayout.blockCount(occupied: [0, 1, 2, 3, 4]) == 1)
        #expect(ShelfLayout.blockCount(occupied: [0, 1, 2, 3, 4, 5]) == 2)
        #expect(ShelfLayout.blockCount(occupied: [0, 7]) == 2)
        #expect(ShelfLayout.slots(inBlock: 1) == 6..<12)
    }
}
