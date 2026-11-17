import BookCore
import SwiftUI

/// What a shelf header can ask the screen to do.
struct ShelfActions {
    let newBook: (ShelfID) -> Void
    let rename: (ShelfSummary) -> Void
    let delete: (ShelfSummary) -> Void
}

/// One shelf (subject): a draggable name plate above its chiseled bookshelf blocks.
struct ShelfRow: View {
    let shelf: ShelfSummary
    let blockCount: Int
    let shelfActions: ShelfActions
    let slotActions: ShelfSlotActions

    @State private var hoveredBook: BookSummary?

    private let scale = PixelTheme.shelfScale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                namePlate
                if let hoveredBook {
                    PixelTooltip {
                        PixelText(hoveredBook.title, color: PixelTheme.title)
                        if hoveredBook.isSigned {
                            PixelText("by \(hoveredBook.author)", color: PixelTheme.textSecondary)
                        }
                    }
                }
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 16 * scale, maximum: 16 * scale), spacing: 4)], alignment: .leading, spacing: 4)
            {
                ForEach(0..<blockCount, id: \.self) { block in
                    let slots = ShelfLayout.slots(inBlock: block)
                    ChiseledBookshelfBlock(
                        shelf: shelf.id,
                        firstSlot: slots.lowerBound,
                        books: slots.map { shelf.book(inSlot: $0) },
                        scale: scale,
                        actions: slotActions,
                        hoveredBook: $hoveredBook
                    )
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.25))
    }

    private var namePlate: some View {
        HStack(spacing: 8) {
            PixelTexture(texture: .bookshelf, scale: PixelTheme.guiScale)
            PixelText(shelf.name, color: PixelTheme.title)
        }
        .padding(6)
        .contentShape(Rectangle())
        .draggable(DragPayload.shelf(shelf.id).encoded) {
            HStack(spacing: 6) {
                PixelTexture(texture: .bookshelf, scale: 3)
                PixelText(shelf.name, color: PixelTheme.title)
            }
        }
        .help("Drag onto a chest on the left to move this shelf")
        .contextMenu {
            Button("New Book…") { shelfActions.newBook(shelf.id) }
            Button("Rename Shelf…") { shelfActions.rename(shelf) }
            Divider()
            Button("Delete Shelf…", role: .destructive) { shelfActions.delete(shelf) }
        }
    }
}
