import BookCore
import SwiftUI

/// Inside a chest: its shelves as rows of chiseled bookshelves, plus the
/// other chests as drop targets for moving shelves.
struct ChestScreen: View {
    let app: AppModel
    @Bindable var model: ChestViewModel

    @State private var prompt: NamePrompt?
    @State private var deletion: DeletionRequest?

    var body: some View {
        ZStack {
            TiledBackground(texture: .darkOakPlanks)
            VStack(spacing: 0) {
                toolbar
                HStack(spacing: 0) {
                    ChestSidebar(chests: model.otherChests) { items, chest in
                        model.handleDrop(items, onChest: chest)
                    }
                    shelves
                }
            }
        }
        .sheet(item: $prompt) { NamePromptSheet(prompt: $0) }
        .deletionConfirmation($deletion)
        .errorAlert($model.errorMessage)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            PixelButton(title: "< Chests", width: 70) { app.goBack() }
                .keyboardShortcut(.cancelAction)
            PixelTexture(texture: .chest, scale: PixelTheme.guiScale)
            PixelText(model.chestID.name, scale: 3, color: PixelTheme.title)
            Spacer()
            PixelButton(title: "New Shelf", width: 80) { promptNewShelf() }
                .keyboardShortcut("n", modifiers: .command)
        }
        .padding(12)
        .background(Color.black.opacity(0.35))
    }

    @ViewBuilder
    private var shelves: some View {
        if model.shelves.isEmpty {
            VStack {
                Spacer()
                PixelText("This chest is empty. Add a shelf for each subject.", color: PixelTheme.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(model.shelves) { shelf in
                        ShelfRow(
                            shelf: shelf,
                            blockCount: model.blockCount(for: shelf),
                            shelfActions: shelfActions,
                            slotActions: slotActions
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: Actions

    private var shelfActions: ShelfActions {
        ShelfActions(
            newBook: { shelf in promptNewBook(on: shelf, slot: nil) },
            rename: { shelf in
                prompt = NamePrompt(
                    title: "Rename Shelf",
                    initialName: shelf.name,
                    confirmTitle: "Rename",
                    maxLength: BookLimits.maxContainerNameLength
                ) { name in
                    model.renameShelf(shelf.id, to: name) ? nil : model.takeErrorMessage()
                }
            },
            delete: { shelf in
                let count = shelf.books.count
                deletion = DeletionRequest(
                    title: "Delete the shelf “\(shelf.name)”?",
                    message: count == 0
                        ? "The empty shelf will be moved to the Trash."
                        : "It and its \(count == 1 ? "book" : "\(count) books") will be moved to the Trash."
                ) {
                    model.deleteShelf(shelf.id)
                }
            }
        )
    }

    private var slotActions: ShelfSlotActions {
        ShelfSlotActions(
            open: { book in app.openBook(book.id) },
            createBook: { shelf, slot in promptNewBook(on: shelf, slot: slot) },
            renameBook: { book in
                prompt = NamePrompt(
                    title: "Rename Book",
                    initialName: book.title,
                    confirmTitle: "Rename",
                    maxLength: BookLimits.maxTitleLength
                ) { title in
                    model.renameBook(book.id, to: title) ? nil : model.takeErrorMessage()
                }
            },
            deleteBook: { book in
                deletion = DeletionRequest(
                    title: "Delete the book “\(book.title)”?",
                    message: "The book and all its pages will be moved to the Trash."
                ) {
                    model.deleteBook(book.id)
                }
            },
            drop: { items, shelf, slot in model.handleDrop(items, onSlot: slot, of: shelf) }
        )
    }

    private func promptNewShelf() {
        prompt = NamePrompt(
            title: "New Shelf (Subject)",
            confirmTitle: "Create",
            maxLength: BookLimits.maxContainerNameLength
        ) { name in
            model.createShelf(named: name) ? nil : model.takeErrorMessage()
        }
    }

    private func promptNewBook(on shelf: ShelfID, slot: Int?) {
        prompt = NamePrompt(
            title: "New Book and Quill",
            confirmTitle: "Write",
            maxLength: BookLimits.maxTitleLength
        ) { title in
            guard let book = model.createBook(titled: title, on: shelf, slot: slot) else {
                return model.takeErrorMessage()
            }
            app.openBook(book)
            return nil
        }
    }
}
