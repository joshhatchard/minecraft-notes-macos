import BookCore
import SwiftUI

/// The shelf's book titles in slot order, so a book can be found without
/// hovering every spine. Each title opens its book and has the book's menu.
struct BookTitleList: View {
    let shelf: ShelfSummary
    let actions: ShelfSlotActions

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(shelf.books) { book in
                BookTitleButton(book: book) { actions.open(book) }
                    .contextMenu {
                        Button("Open") { actions.open(book) }
                        Button("Rename…") { actions.renameBook(book) }
                        Divider()
                        Button("Delete…", role: .destructive) { actions.deleteBook(book) }
                    }
                    .uiTarget(UITargetID.bookTitle(book.title, onShelf: shelf.name))
            }
        }
    }
}

private struct BookTitleButton: View {
    let book: BookSummary
    let open: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 4) {
                PixelTexture(texture: .bookAndQuill, scale: 1)
                PixelText(book.title, color: isHovered ? PixelTheme.textHighlighted : PixelTheme.text)
                if book.isSigned {
                    PixelText("(signed)", color: PixelTheme.textSecondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isHovered ? PixelTheme.hoverHighlight : Color.black.opacity(0.3))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(book.isSigned ? "\(book.title) by \(book.author)" : "Open \(book.title)")
    }
}

/// Lays children out left to right, wrapping onto new rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: rows.width, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, width: bounds.width)
        for (index, origin) in rows.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (origins: [CGPoint], width: CGFloat, height: CGFloat) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (origins, maxX, y + rowHeight)
    }
}
