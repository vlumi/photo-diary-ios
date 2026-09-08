import SwiftUI

/// Photos that share one exact coordinate — a cluster zooming can't
/// separate. Shown as a thumbnail grid; tapping one hands the photo
/// back for the viewer.
struct ClusterPhotosSheet: View {
    let photos: [Photo]
    let loader: any ImageLoader
    let onSelect: (Photo) -> Void
    let onDismiss: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(photos) { photo in
                        Button {
                            onSelect(photo)
                        } label: {
                            PhotoThumbnail(url: photo.thumbnailURL, loader: loader)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(photo.title.isEmpty ? "Photo \(photo.id)" : photo.title)
                    }
                }
            }
            .navigationTitle("\(photos.count) photos here")
            .navigationBarTitleDisplayModeInlineIfAvailable()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}

extension View {
    fileprivate func navigationBarTitleDisplayModeInlineIfAvailable() -> some View {
        #if os(iOS)
        return self.navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }
}
