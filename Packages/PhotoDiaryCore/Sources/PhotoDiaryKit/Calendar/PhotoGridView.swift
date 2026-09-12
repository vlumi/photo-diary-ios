import SwiftUI

/// Grid of photos for a year+month slice of a gallery. Sectioned by
/// day; each cell is a PhotoThumbnail that opens the paging viewer on
/// tap.
///
/// Loads its own photo list from the active instance in .task — no
/// upstream fetching needed. Empty and error states are rendered in
/// place so the caller doesn't have to.
public struct PhotoGridView: View {
    private let galleryId: String
    private let year: Int
    private let month: Int?

    @Environment(InstanceRegistry.self) private var registry
    @Environment(\.imageLoader) private var loaderBox
    @Environment(MapFocusStore.self) private var focus
    @State private var state: LoadState<[PhotoCalendar.DaySection]> = .loading
    @State private var attempt = 0
    @State private var presented: PhotoPagerSelection?

    public init(galleryId: String, year: Int, month: Int? = nil) {
        self.galleryId = galleryId
        self.year = year
        self.month = month
    }

    public var body: some View {
        content
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayModeInline()
            .task(id: reloadKey) { await load() }
            .photoViewerCover(item: $presented, loader: loaderBox.loader) { photo in
                presented = nil
                focus.show(photo)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView(
                "No photos",
                systemImage: "photo.on.rectangle",
                description: Text("This period has no photos.")
            )
        case .failed(let failure):
            LoadFailureView(title: "Couldn't load photos", failure: failure) { attempt += 1 }
        case .loaded(let sections):
            grid(sections)
        }
    }

    private func grid(_ sections: [PhotoCalendar.DaySection]) -> some View {
        // The viewer pages through the whole grid in display order.
        let ordered = sections.flatMap(\.photos)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: .sectionHeaders) {
                ForEach(sections) { section in
                    Section {
                        LazyVGrid(columns: gridColumns, spacing: 2) {
                            ForEach(section.photos) { photo in
                                Button {
                                    if let i = ordered.firstIndex(of: photo) {
                                        presented = PhotoPagerSelection(photos: ordered, index: i)
                                    }
                                } label: {
                                    PhotoThumbnail(
                                        url: photo.thumbnailURL,
                                        loader: loaderBox.loader
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(photo.accessibilityDescription)
                                .accessibilityHint("Opens the photo.")
                            }
                        }
                    } header: {
                        Text(dayLabel(section.day))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial)
                    }
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    }

    private var navTitle: String {
        if let month {
            return String(format: "%04d-%02d", year, month)
        }
        return String(year)
    }

    private var reloadKey: String {
        "\(galleryId):\(year):\(month ?? -1):\(attempt)"
    }

    private func dayLabel(_ day: Int) -> String {
        if let month {
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
        return "Day \(day)"
    }

    private func load() async {
        guard let instance = registry.activeInstance else {
            state = .failed(LoadFailure(message: "No active instance."))
            return
        }
        await LoadState.load(
            cached: { await instance.cachedPhotos(inGallery: galleryId).map(sections) },
            fresh: { sections(try await instance.listPhotos(inGallery: galleryId)) },
            isEmpty: \.isEmpty,
            onFailure: { registry.evictIfAccessLost($0) }
        ) { state = $0 }
    }

    private func sections(_ all: [Photo]) -> [PhotoCalendar.DaySection] {
        let scope: [Photo]
        if let month {
            scope = PhotoCalendar.photos(in: year, month: month, of: all)
        } else {
            scope = PhotoCalendar.photos(in: year, of: all)
        }
        return PhotoCalendar.groupByDay(scope)
    }
}

// navigationBarTitleDisplayMode is iOS-only; wrap it in a helper so
// swift test on macOS (which sees this file) still compiles.
extension View {
    fileprivate func navigationBarTitleDisplayModeInline() -> some View {
        #if canImport(UIKit)
        return self.navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }

    /// The viewer as a sheet: a swipe down closes it, the way a
    /// photo is put away everywhere else.
    fileprivate func photoViewerCover(
        item: Binding<PhotoPagerSelection?>,
        loader: any ImageLoader,
        onShowOnMap: @escaping (Photo) -> Void
    ) -> some View {
        self.sheet(item: item) { selection in
            PhotoPagerSheet(
                selection: selection, loader: loader,
                onDismiss: { item.wrappedValue = nil },
                onShowOnMap: onShowOnMap
            )
        }
    }
}
