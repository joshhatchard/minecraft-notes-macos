import BookCore
import SwiftUI

/// The signing page: "Enter Book Title:", the title, "by" the author, and the
/// warning that signing makes the book read-only. Confirming happens with the
/// "Sign and Close" button below the book.
struct SignBookForm: View {
    @Bindable var model: BookEditorViewModel
    let scale: CGFloat

    private typealias Geometry = BookCanvasGeometry
    private let textWidth = CGFloat(BookLimits.lineWidth)

    var body: some View {
        ZStack(alignment: .topLeading) {
            row(top: Geometry.signHeadingTop) {
                PixelText("Enter Book Title:", scale: scale, color: PixelTheme.ink, shadow: false)
            }
            row(top: Geometry.signTitleTop) {
                PixelTextField(
                    text: $model.signingTitle,
                    maxLength: BookLimits.maxTitleLength,
                    scale: scale,
                    alignment: .center,
                    ink: PixelTheme.ink,
                    framed: false
                )
                .uiTarget(UITargetID.signTitleField)
            }
            row(top: Geometry.signAuthorTop) {
                HStack(spacing: 0) {
                    PixelText("by", scale: scale, color: Color(white: 0.25), shadow: false)
                    PixelTextField(
                        text: $model.signingAuthor,
                        maxLength: BookLimits.maxAuthorLength,
                        scale: scale,
                        ink: Color(white: 0.25),
                        framed: false
                    )
                    .uiTarget(UITargetID.signAuthorField)
                }
            }
            row(top: Geometry.signWarningTop) {
                PixelText(
                    "Note! When you sign the book, it will no longer be editable.",
                    scale: scale,
                    color: PixelTheme.ink,
                    shadow: false
                )
                .multilineTextAlignment(.center)
            }
        }
    }

    private func row(top: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(width: textWidth * scale)
            .padding(.leading, Geometry.textOrigin.x * scale)
            .padding(.top, top * scale)
    }
}
