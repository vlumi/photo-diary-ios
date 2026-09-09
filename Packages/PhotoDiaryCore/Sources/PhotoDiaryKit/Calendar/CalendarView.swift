import SwiftUI

/// Root of the calendar surface. Owns the navigation stack; each row
/// pushes a typed CalendarRoute so back-navigation and deep links can
/// both target the same destinations.
public struct CalendarView: View {
    @Environment(InstanceRegistry.self) private var registry
    @Environment(\.restoration) private var restoration
    @State private var path: [CalendarRoute] = []

    public init() {}

    public var body: some View {
        NavigationStack(path: $path) {
            root
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            registry.leaveScope()
                        } label: {
                            Label("Photo Diary", systemImage: "square.grid.2x2")
                        }
                    }
                }
                .navigationDestination(for: CalendarRoute.self) { route in
                    switch route {
                    case .years(let galleryId):
                        YearListView(galleryId: galleryId)
                    case .months(let galleryId, let year):
                        MonthListView(galleryId: galleryId, year: year)
                    case .grid(let galleryId, let year, let month):
                        PhotoGridView(galleryId: galleryId, year: year, month: month)
                    }
                }
        }
        // The path belongs to its scope: restored when one opens
        // (including at launch), saved as it changes.
        .onChange(of: registry.scope, initial: true) {
            guard let scope = registry.scope else { return }
            path = restoration.load([CalendarRoute].self, forKey: "calendar." + scope.key) ?? []
        }
        .onChange(of: path) {
            guard let scope = registry.scope else { return }
            restoration.save(path, forKey: "calendar." + scope.key)
        }
    }

    /// A gallery in scope skips the gallery list.
    @ViewBuilder
    private var root: some View {
        if let galleryId = registry.scope?.galleryId {
            YearListView(galleryId: galleryId)
        } else {
            GalleryListView()
        }
    }
}

public enum CalendarRoute: Hashable, Codable, Sendable {
    case years(galleryId: String)
    case months(galleryId: String, year: Int)
    case grid(galleryId: String, year: Int, month: Int?)
}

// MARK: - Gallery list

struct GalleryListView: View {
    @Environment(InstanceRegistry.self) private var registry
    @State private var state: LoadState<[Gallery]> = .loading
    @State private var attempt = 0

    var body: some View {
        content
            .navigationTitle(registry.activeInstance?.displayName ?? "Photo Diary")
            .task(id: "\(registry.scope?.instanceId ?? ""):\(attempt)") { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView(
                "No galleries",
                systemImage: "photo.on.rectangle.angled",
                description: Text("This instance has no galleries you can see.")
            )
        case .failed(let failure):
            LoadFailureView(title: "Couldn't load galleries", failure: failure) { attempt += 1 }
        case .loaded(let galleries):
            List(galleries) { gallery in
                NavigationLink(value: CalendarRoute.years(galleryId: gallery.id)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gallery.title).font(.headline)
                        if !gallery.description.isEmpty {
                            Text(gallery.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let count = gallery.photoCount {
                            Text("\(count) photos")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private func load() async {
        guard let instance = registry.activeInstance else {
            state = .failed(LoadFailure(message: "No active instance."))
            return
        }
        await LoadState.load(
            cached: { await instance.cachedGalleries() },
            fresh: { try await instance.listGalleries() },
            isEmpty: \.isEmpty,
            onFailure: { registry.evictIfAccessLost($0) }
        ) { state = $0 }
    }
}

// MARK: - Year list

struct YearListView: View {
    let galleryId: String

    @Environment(InstanceRegistry.self) private var registry
    @State private var state: LoadState<[Int]> = .loading
    @State private var attempt = 0

    var body: some View {
        content
            .navigationTitle("Years")
            .task(id: "\(galleryId):\(attempt)") {
                await loadCalendarSlice(of: galleryId, from: registry, into: { state = $0 }) {
                    PhotoCalendar.years(in: $0)
                }
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
                description: Text("This gallery has no photos yet.")
            )
        case .failed(let failure):
            LoadFailureView(title: "Couldn't load photos", failure: failure) { attempt += 1 }
        case .loaded(let years):
            List(years, id: \.self) { year in
                NavigationLink(
                    value: CalendarRoute.months(galleryId: galleryId, year: year)
                ) {
                    Text(String(year)).font(.title3)
                }
            }
        }
    }
}

// MARK: - Month list

struct MonthListView: View {
    let galleryId: String
    let year: Int

    @Environment(InstanceRegistry.self) private var registry
    @State private var state: LoadState<[Int]> = .loading
    @State private var attempt = 0

    var body: some View {
        content
            .navigationTitle(String(year))
            .task(id: "\(galleryId):\(year):\(attempt)") {
                await loadCalendarSlice(of: galleryId, from: registry, into: { state = $0 }) {
                    PhotoCalendar.months(in: year, of: $0)
                }
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
                description: Text("This year has no photos.")
            )
        case .failed(let failure):
            LoadFailureView(title: "Couldn't load photos", failure: failure) { attempt += 1 }
        case .loaded(let months):
            List {
                // Year-wide grid entry so the user can browse the whole
                // year without picking a month.
                NavigationLink(
                    value: CalendarRoute.grid(galleryId: galleryId, year: year, month: nil)
                ) {
                    Text("All of \(String(year))").font(.headline)
                }
                ForEach(months, id: \.self) { month in
                    NavigationLink(
                        value: CalendarRoute.grid(galleryId: galleryId, year: year, month: month)
                    ) {
                        Text(monthName(month))
                    }
                }
            }
        }
    }

    private func monthName(_ month: Int) -> String {
        let symbols = DateFormatter().monthSymbols ?? []
        guard (1...12).contains(month), month - 1 < symbols.count else {
            return String(format: "%02d", month)
        }
        return symbols[month - 1]
    }
}

/// Years and months both derive from the gallery's full photo list
/// (cached by the instance, so the second hop is free).
@MainActor
private func loadCalendarSlice(
    of galleryId: String, from registry: InstanceRegistry,
    into update: (LoadState<[Int]>) -> Void, derive: ([Photo]) -> [Int]
) async {
    guard let instance = registry.activeInstance else {
        update(.failed(LoadFailure(message: "No active instance.")))
        return
    }
    await LoadState.load(
        cached: { await instance.cachedPhotos(inGallery: galleryId).map(derive) },
        fresh: { derive(try await instance.listPhotos(inGallery: galleryId)) },
        isEmpty: \.isEmpty,
        onFailure: { registry.evictIfAccessLost($0) },
        into: update
    )
}
