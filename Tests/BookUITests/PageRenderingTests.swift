import BookAssets
import BookCore
import CoreGraphics
import Testing

@testable import BookUI

/// Checks that AppKit lays page text out exactly as the page fitter counts it,
/// so the 14-line rule matches what is drawn.
@MainActor
@Suite("Page rendering matches the page rules")
struct PageRenderingTests {
    let fitter = PageFitter(measurer: FontGlyphMeasurer(fontName: FontRegistry.pixelFontName, size: 8))

    nonisolated static let samples: [String] = [
        "",
        "Hello",
        String(repeating: "a", count: 19),
        String(repeating: "a", count: 20),
        String(repeating: "i", count: 57),
        String(repeating: "i", count: 58),
        "Newton's first law: an object stays at rest or in uniform motion unless a net force acts on it.",
        "Line one\nLine two\n\nLine four\n",
        String(repeating: "word ", count: 40),
        "supercalifragilisticexpialidocious and more words after it",
        String(repeating: "@", count: 16 * 3),
        Array(repeating: "x", count: 14).joined(separator: "\n"),
    ]

    @Test func bundledAssetsArePresent() {
        for texture in AssetCatalog.Texture.allCases {
            #expect(AssetCatalog.url(for: texture) != nil, "missing texture \(texture.rawValue)")
        }
        for font in AssetCatalog.FontFile.allCases {
            #expect(AssetCatalog.url(for: font) != nil, "missing font \(font.rawValue)")
        }
        for sound in AssetCatalog.SoundFile.allCases {
            #expect(AssetCatalog.url(for: sound) != nil, "missing sound \(sound.rawValue)")
        }
    }

    @Test func fontMeasurerAgreesWithTheReferenceTable() {
        FontRegistry.registerBundledFonts()
        let reference = MinecraftGlyphMetrics()
        let measurer = FontGlyphMeasurer(fontName: FontRegistry.pixelFontName, size: 8)
        for scalar in 32...126 {
            let character = Character(Unicode.Scalar(UInt8(scalar)))
            #expect(measurer.advance(of: character) == reference.advance(of: character), "width of \(character)")
        }
    }

    @Test(arguments: samples, [1.0, 2.0, 3.0])
    func appKitLineCountMatchesTheFitter(text: String, scale: Double) {
        FontRegistry.registerBundledFonts()
        let rendered = PageTextLayout.renderedLineCount(of: text, scale: scale)
        #expect(rendered == fitter.lineCount(of: text))
    }

    @Test func canvasScaleIsTheLargestIntegerThatFits() {
        #expect(BookCanvasGeometry.scale(fitting: CGSize(width: 650, height: 900)) == 3)
        #expect(BookCanvasGeometry.scale(fitting: CGSize(width: 100, height: 100)) == 1)
    }
}
