import BookCore
import SwiftUI

/// One chiseled bookshelf block: six book slots in two rows of three, drawn
/// from the empty and occupied textures.
struct ChiseledBookshelfBlock: View {
    /// Slot rectangles in texels, in slot order (top row left to right, then bottom row).
    static let slotRects: [CGRect] = [
        CGRect(x: 1, y: 1, width: 4, height: 6),
        CGRect(x: 6, y: 1, width: 4, height: 6),
        CGRect(x: 11, y: 1, width: 4, height: 6),
        CGRect(x: 1, y: 9, width: 4, height: 6),
        CGRect(x: 6, y: 9, width: 4, height: 6),
        CGRect(x: 11, y: 9, width: 4, height: 6),
    ]

    let shelf: ShelfID
    /// Global slot index of this block's first slot.
    let firstSlot: Int
    /// Books for this block's six slots, `nil` where empty.
    let books: [BookSummary?]
    let scale: CGFloat
    let actions: ShelfSlotActions
    @Binding var hoveredBook: BookSummary?

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelTexture(texture: .chiseledBookshelfEmpty, scale: scale)
            ForEach(Self.slotRects.indices, id: \.self) { index in
                let rect = Self.slotRects[index]
                ShelfSlotView(
                    shelf: shelf,
                    slot: firstSlot + index,
                    book: books[index],
                    textureRect: rect,
                    scale: scale,
                    actions: actions,
                    hoveredBook: $hoveredBook
                )
                .padding(.leading, rect.minX * scale)
                .padding(.top, rect.minY * scale)
            }
        }
        .frame(width: 16 * scale, height: 16 * scale, alignment: .topLeading)
    }
}

/// What a shelf slot can ask the screen to do.
struct ShelfSlotActions {
    let open: (BookSummary) -> Void
    let createBook: (ShelfID, Int) -> Void
    let renameBook: (BookSummary) -> Void
    let deleteBook: (BookSummary) -> Void
    let drop: ([String], ShelfID, Int) -> Bool
}

/// A single slot: shows a book (drag it, click to open) or an empty gap
/// (click to write a new book there). Both accept dropped books.
struct ShelfSlotView: View {
    let shelf: ShelfID
    let slot: Int
    let book: BookSummary?
    let textureRect: CGRect
    let scale: CGFloat
    let actions: ShelfSlotActions
    @Binding var hoveredBook: BookSummary?

    @State private var isHovered = false
    @State private var isDropTarget = false

    var body: some View {
        Group {
            if let book {
                bookSlot(book)
            } else {
                emptySlot
            }
        }
        .onHover { hovering in
                isHovered = hovering
                if hovering {
                    hoveredBook = book
                } else if hoveredBook?.id == book?.id {
                    hoveredBook = nil
                }
            }
            .dropDestination(for: String.self) { items, _ in
                actions.drop(items, shelf, slot)
            } isTargeted: {
                isDropTarget = $0
            }
            .uiTarget(UITargetID.slot(slot, onShelf: shelf.name))
    }

    private func bookSlot(_ book: BookSummary) -> some View {
        face(PixelTexture(texture: .chiseledBookshelfOccupied, scale: scale, crop: textureRect))
            .onTapGesture { actions.open(book) }
            .draggable(DragPayload.book(book.id).encoded) {
                PixelTexture(texture: .bookAndQuill, scale: 3)
            }
            .contextMenu {
                Button("Open") { actions.open(book) }
                Button("Rename…") { actions.renameBook(book) }
                Divider()
                Button("Delete…", role: .destructive) { actions.deleteBook(book) }
            }
            .help(book.isSigned ? "\(book.title) by \(book.author)" : book.title)
            .accessibilityLabel(Text("Book \(book.title)"))
            .accessibilityAddTraits(.isButton)
    }

    private var emptySlot: some View {
        Button {
            actions.createBook(shelf, slot)
        } label: {
            face(EmptySlotMark(isHovered: isHovered, scale: scale))
        }
        .buttonStyle(.plain)
        .contextMenu {
                Button("New Book Here…") { actions.createBook(shelf, slot) }
            }
            .help("Empty slot: click to write a new book here")
            .accessibilityLabel(Text("Empty slot, write a new book"))
            .accessibilityAddTraits(.isButton)
    }

    /// The slot's picture at slot size, with the hover/drop highlight, as one
    /// clickable rectangle.
    ///
    /// The gestures must be attached *after* `contentShape`: an empty slot
    /// draws nothing opaque, and SwiftUI only hit-tests what is drawn, so
    /// without it clicks on empty slots were silently ignored. The highlight
    /// must not take part in hit testing, or it would swallow clicks while
    /// the pointer hovers.
    private func face(_ picture: some View) -> some View {
        picture
            .frame(width: textureRect.width * scale, height: textureRect.height * scale)
            .overlay {
                Group {
                    if isDropTarget {
                        PixelTheme.dropHighlight
                    } else if isHovered {
                        PixelTheme.hoverHighlight
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
    }
}

/// A faint quill-and-plus mark in an empty slot, so it reads as "write here"
/// when hovered.
private struct EmptySlotMark: View {
    let isHovered: Bool
    let scale: CGFloat

    var body: some View {
        PixelText("+", scale: scale / 2, color: PixelTheme.textHighlighted)
            .opacity(isHovered ? 1 : 0)
    }
}
