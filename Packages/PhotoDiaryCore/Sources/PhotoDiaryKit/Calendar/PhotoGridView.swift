import SwiftUI

/// Grid of photos for a year+month slice of a gallery. Sectioned by
/// day; each cell is a PhotoThumbnail that opens PhotoViewerSheet on
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
    @State private var state: LoadState = .loading
    @State private var presented: Photo?

    private enum LoadState {
        case loading
        case loaded([PhotoCalendar.DaySection])
        case failed(String)
        case empty
    }

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
            .photoViewerCover(item: $presented, loader: loaderBox.loader)
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
        case .failed(let message):
            ContentUnavailableView(
                "Couldn't load photos",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .loaded(let sections):
            grid(sections)
        }
    }

    private func grid(_ sections: [PhotoCalendar.DaySection]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: .sectionHeaders) {
                ForEach(sections) { section in
                    Section {
                        LazyVGrid(columns: gridColumns, spacing: 2) {
                            ForEach(section.photos) { photo in
                                Button {
                                    presented = photo
                                } label: {
                                    PhotoThumbnail(
                                        url: photo.thumbnailURL,
                                        loader: loaderBox.loader
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(accessibilityLabel(for: photo))
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
        "\(galleryId):\(year):\(month ?? -1)"
    }

    private func dayLabel(_ day: Int) -> String {
        if let month {
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
        return "Day \(day)"
    }

    private func accessibilityLabel(for photo: Photo) -> String {
        photo.title.isEmpty ? "Photo \(photo.id)" : photo.title
    }

    private func load() async {
        state = .loading
        guard let instance = registry.activeInstance else {
            state = .failed("No active instance.")
            return
        }
        do {
            let all = try await instance.listPhotos(inGallery: galleryId)
            let scope: [Photo]
            if let month {
                scope = PhotoCalendar.photos(in: year, month: month, of: all)
            } else {
                scope = PhotoCalendar.photos(in: year, of: all)
            }
            if scope.isEmpty {
                state = .empty
            } else {
                state = .loaded(PhotoCalendar.groupByDay(scope))
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
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

    /// Shared iOS-vs-macOS shim: fullScreenCover on iOS, sheet on
    /// macOS. AppShell had its own version wired only for the
    /// placeholder preview button — this is the one every real
    /// calendar / map surface routes through.
    fileprivate func photoViewerCover(
        item: Binding<Photo?>,
        loader: any ImageLoader
    ) -> some View {
        #if canImport(UIKit)
        return self.fullScreenCover(item: item) { photo in
            PhotoViewerSheet(photo: photo, loader: loader) { item.wrappedValue = nil }
        }
        #else
        return self.sheet(item: item) { photo in
            PhotoViewerSheet(photo: photo, loader: loader) { item.wrappedValue = nil }
        }
        #endif
    }
}
