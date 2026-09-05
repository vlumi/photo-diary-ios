import SwiftUI

/// Root of the calendar surface. Owns the navigation stack; each row
/// pushes a typed CalendarRoute so back-navigation and deep links can
/// both target the same destinations.
public struct CalendarView: View {
    @State private var path: [CalendarRoute] = []

    public init() {}

    public var body: some View {
        NavigationStack(path: $path) {
            GalleryListView()
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
    }
}

public enum CalendarRoute: Hashable, Sendable {
    case years(galleryId: String)
    case months(galleryId: String, year: Int)
    case grid(galleryId: String, year: Int, month: Int?)
}

// MARK: - Gallery list

struct GalleryListView: View {
    @Environment(InstanceRegistry.self) private var registry
    @State private var state: LoadState = .loading

    private enum LoadState {
        case loading
        case loaded([Gallery])
        case failed(String)
    }

    var body: some View {
        content
            .navigationTitle(registry.activeInstance?.displayName ?? "Photo Diary")
            .task(id: registry.activeInstanceId) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView(
                "Couldn't load galleries",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
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
                        Text("\(gallery.photoCount) photos")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func load() async {
        state = .loading
        guard let instance = registry.activeInstance else {
            state = .failed("No active instance.")
            return
        }
        do {
            let galleries = try await instance.listGalleries()
            state = .loaded(galleries)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Year list

struct YearListView: View {
    let galleryId: String

    @Environment(InstanceRegistry.self) private var registry
    @State private var years: [Int] = []
    @State private var loadFailed: String?

    var body: some View {
        List {
            if let loadFailed {
                Text(loadFailed).foregroundStyle(.red)
            }
            ForEach(years, id: \.self) { year in
                NavigationLink(
                    value: CalendarRoute.months(galleryId: galleryId, year: year)
                ) {
                    Text(String(year)).font(.title3)
                }
            }
        }
        .navigationTitle("Years")
        .task(id: galleryId) { await load() }
    }

    private func load() async {
        loadFailed = nil
        guard let instance = registry.activeInstance else { return }
        do {
            let photos = try await instance.listPhotos(inGallery: galleryId)
            years = PhotoCalendar.years(in: photos)
        } catch {
            loadFailed = error.localizedDescription
        }
    }
}

// MARK: - Month list

struct MonthListView: View {
    let galleryId: String
    let year: Int

    @Environment(InstanceRegistry.self) private var registry
    @State private var months: [Int] = []
    @State private var loadFailed: String?

    var body: some View {
        List {
            if let loadFailed {
                Text(loadFailed).foregroundStyle(.red)
            }
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
        .navigationTitle(String(year))
        .task(id: "\(galleryId):\(year)") { await load() }
    }

    private func monthName(_ month: Int) -> String {
        let symbols = DateFormatter().monthSymbols ?? []
        guard (1...12).contains(month), month - 1 < symbols.count else {
            return String(format: "%02d", month)
        }
        return symbols[month - 1]
    }

    private func load() async {
        loadFailed = nil
        guard let instance = registry.activeInstance else { return }
        do {
            let photos = try await instance.listPhotos(inGallery: galleryId)
            months = PhotoCalendar.months(in: year, of: photos)
        } catch {
            loadFailed = error.localizedDescription
        }
    }
}
