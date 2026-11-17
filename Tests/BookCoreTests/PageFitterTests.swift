import BookCore
import Testing

@Suite("Page limits")
struct PageFitterTests {
    let fitter = PageFitter()

    private func edit(_ text: String, insert replacement: String, at offset: Int? = nil) -> String? {
        let index = offset.map { text.index(text.startIndex, offsetBy: $0) } ?? text.endIndex
        return fitter.applyEdit(to: text, replacing: index..<index, with: replacement)
    }

    @Test func emptyPageFits() {
        #expect(fitter.check("") == .fits)
    }

    @Test func exactly256CharactersFit() {
        // 256 "i" glyphs wrap to 5 lines, well under 14.
        let text = String(repeating: "i", count: 256)
        #expect(fitter.check(text) == .fits)
    }

    @Test func the257thCharacterIsRejected() {
        let text = String(repeating: "i", count: 257)
        #expect(fitter.check(text) == .tooManyCharacters(257))
    }

    @Test func fourteenLinesFitButFifteenDoNot() {
        let fourteen = Array(repeating: "x", count: 14).joined(separator: "\n")
        #expect(fitter.check(fourteen) == .fits)
        #expect(fitter.check(fourteen + "\n") == .tooManyLines(15))
    }

    @Test func wrappingCountsTowardsTheLineLimit() {
        // 14 full lines of 19 "a" = 266 characters, so use wide words with few characters:
        // each "@@@@@@@@@@@@@@@@" (16 × 7 = 112 px) fills one line.
        let line = String(repeating: "@", count: 16)
        let fourteenLines = String(repeating: line, count: 14)
        #expect(fourteenLines.count == 224)
        #expect(fitter.check(fourteenLines) == .fits)
        #expect(fitter.check(fourteenLines + "@") == .tooManyLines(15))
    }

    @Test func newlinesCountAsCharacters() {
        #expect(fitter.characterCount(of: "a\nb") == 3)
    }

    @Test func combinedEmojiCountAsOneCharacter() {
        #expect(fitter.characterCount(of: "👨‍👩‍👧") == 1)
        #expect(fitter.characterCount(of: "é") == 1)
    }

    @Test func typingWithinLimitsIsApplied() {
        #expect(edit("Hello", insert: " world") == "Hello world")
    }

    @Test func typingPastTheCharacterLimitIsRejected() {
        let full = String(repeating: "i", count: 256)
        #expect(edit(full, insert: "i") == nil)
    }

    @Test func typingANewlineOnTheLastLineIsRejected() {
        let fourteen = Array(repeating: "x", count: 14).joined(separator: "\n")
        #expect(edit(fourteen, insert: "\n") == nil)
    }

    @Test func longPasteIsClippedToWhatFits() {
        let result = edit("", insert: String(repeating: "i", count: 300))
        #expect(result?.count == 256)
    }

    @Test func pasteInTheMiddleKeepsTheSuffix() {
        let result = edit("ab", insert: String(repeating: "i", count: 300), at: 1)
        #expect(result?.first == "a")
        #expect(result?.last == "b")
        #expect(result?.count == 256)
    }

    @Test func pasteIsSanitised() {
        #expect(edit("", insert: "a\tb\r\nc\u{0007}") == "a b\nc")
    }

    @Test func deletingFromAnOverfullImportedPageIsAllowed() {
        let overfull = String(repeating: "i", count: 300)
        let start = overfull.startIndex
        let result = fitter.applyEdit(to: overfull, replacing: start..<overfull.index(after: start), with: "")
        #expect(result?.count == 299)
    }

    @Test func noOpEditReturnsNil() {
        let text = "abc"
        #expect(fitter.applyEdit(to: text, replacing: text.startIndex..<text.startIndex, with: "") == nil)
    }
}

@Suite("Page text sanitising")
struct PageTextTests {
    @Test func normalisesLineEndingsAndTabs() {
        #expect(PageText.sanitize("a\r\nb\rc\td") == "a\nb\nc d")
    }

    @Test func removesControlCharactersButKeepsUnicode() {
        #expect(PageText.sanitize("é\u{0000}ü\u{001B}🙂") == "éü🙂")
    }
}
