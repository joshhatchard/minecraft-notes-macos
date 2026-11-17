import BookCore
import SwiftUI

/// The Book and Quill screen: one page of the book with page arrows, the page
/// counter and the Sign / Done buttons, laid out like the game and scaled by
/// the largest integer factor that fits the window.
struct BookEditorScreen: View {
    let app: AppModel
    @Bindable var model: BookEditorViewModel

    @State private var flipAngle: Double = 0
    @State private var isFlipping = false

    private typealias Geometry = BookCanvasGeometry

    var body: some View {
        ZStack {
            TiledBackground(texture: .darkOakPlanks)
            VStack(spacing: 8) {
                header
                GeometryReader { proxy in
                    let scale = Geometry.scale(fitting: proxy.size)
                    canvas(scale: scale)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .padding(16)
        }
        .errorAlert($model.errorMessage)
    }

    private var header: some View {
        HStack(spacing: 12) {
            PixelText(model.book.title, color: PixelTheme.title)
            PixelText(
                model.book.isSigned ? "by \(model.book.author)" : "Book and Quill",
                color: PixelTheme.textSecondary
            )
            Spacer()
        }
    }

    private func canvas(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            page(scale: scale)
                .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.35)
            if model.mode == .pages {
                arrows(scale: scale)
            }
            buttons(scale: scale)
        }
        .frame(width: Geometry.canvasSize.width * scale, height: Geometry.canvasSize.height * scale, alignment: .topLeading)
    }

    // MARK: Page

    private func page(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            PixelTexture(texture: .book, scale: scale, crop: Geometry.bookTextureCrop)
                .padding(.leading, Geometry.bookOrigin.x * scale)
                .padding(.top, Geometry.bookOrigin.y * scale)
            switch model.mode {
            case .pages: pageContent(scale: scale)
            case .signing: SignBookForm(model: model, scale: scale)
            }
        }
    }

    private func pageContent(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            PixelText(model.pageLabel, scale: scale, color: PixelTheme.pageNumberInk, shadow: false)
                .frame(width: Geometry.pageLabelTrailingX * scale, alignment: .trailing)
                .padding(.top, Geometry.pageLabelTop * scale)
            PageTextView(model: model, scale: scale)
                .id(PageIdentity(index: model.pageIndex, scale: scale))
                .frame(width: PageTextLayout.width * scale, height: PageTextLayout.height * scale)
                .padding(.leading, Geometry.textOrigin.x * scale)
                .padding(.top, Geometry.textOrigin.y * scale)
        }
    }

    private func arrows(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            if model.canTurnBack {
                PageArrowButton(direction: .backward, scale: scale, help: "Previous page") { turn(forward: false) }
                    .keyboardShortcut("[", modifiers: .command)
                    .padding(.leading, Geometry.backArrowOrigin.x * scale)
                    .padding(.top, Geometry.backArrowOrigin.y * scale)
            }
            if model.canTurnForward {
                PageArrowButton(
                    direction: .forward,
                    scale: scale,
                    help: model.forwardAddsPage ? "Add page" : "Next page"
                ) { turn(forward: true) }
                .keyboardShortcut("]", modifiers: .command)
                .padding(.leading, Geometry.forwardArrowOrigin.x * scale)
                .padding(.top, Geometry.forwardArrowOrigin.y * scale)
            }
        }
    }

    // MARK: Buttons

    @ViewBuilder
    private func buttons(scale: CGFloat) -> some View {
        Group {
            switch model.mode {
            case .pages where model.isEditable:
                HStack(spacing: (Geometry.secondButtonX - Geometry.halfButtonWidth) * scale) {
                    PixelButton(title: "Sign", width: Geometry.halfButtonWidth, scale: scale) { model.beginSigning() }
                    PixelButton(title: "Done", width: Geometry.halfButtonWidth, scale: scale) { app.goBack() }
                        .keyboardShortcut(.cancelAction)
                }
            case .pages:
                PixelButton(title: "Done", width: Geometry.fullButtonWidth, scale: scale) { app.goBack() }
                    .keyboardShortcut(.cancelAction)
            case .signing:
                HStack(spacing: (Geometry.secondButtonX - Geometry.halfButtonWidth) * scale) {
                    PixelButton(
                        title: "Sign and Close",
                        width: Geometry.halfButtonWidth,
                        scale: scale,
                        isEnabled: model.canConfirmSigning
                    ) {
                        if model.confirmSigning() {
                            app.goBack()
                        }
                    }
                    PixelButton(title: "Cancel", width: Geometry.halfButtonWidth, scale: scale) { model.cancelSigning() }
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(.top, Geometry.buttonTop * scale)
    }

    // MARK: Page flip

    /// Swings the page edge-on around the spine, swaps the page, and swings it back.
    private func turn(forward: Bool) {
        guard !isFlipping else { return }
        isFlipping = true
        withAnimation(.easeIn(duration: 0.11)) {
            flipAngle = forward ? -88 : 88
        } completion: {
            if forward {
                model.turnForward()
            } else {
                model.turnBack()
            }
            withAnimation(.easeOut(duration: 0.13)) {
                flipAngle = 0
            } completion: {
                isFlipping = false
            }
        }
    }
}

/// Recreates the page text view when the page or the scale changes.
private struct PageIdentity: Hashable {
    let index: Int
    let scale: CGFloat
}
