import SwiftUI

/// Callout shown above a selected pin: one photo's thumbnail, or for a
/// pile a mini pager with chevrons and a counter. Tapping the thumbnail
/// opens the full viewer at that photo. Sized to sit over the map
/// without hiding much of it.
struct MapPhotoCallout: View {
    let photos: [Photo]
    let loader: any ImageLoader
    let onOpen: (Int) -> Void

    @State private var index = 0

    private let thumbSize: CGFloat = 132

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                if photos.count > 1 {
                    chevron("chevron.left", enabled: index > 0) { index -= 1 }
                }
                thumbnail
                if photos.count > 1 {
                    chevron("chevron.right", enabled: index < photos.count - 1) { index += 1 }
                }
            }
            if photos.indices.contains(index) {
                Text(caption(for: photos[index]))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6, y: 2)
        .onChange(of: photos.map(\.id)) { index = 0 }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if photos.indices.contains(index) {
            let photo = photos[index]
            Button {
                onOpen(index)
            } label: {
                PhotoThumbnail(url: photo.thumbnailURL, loader: loader)
                    .frame(width: thumbSize, height: thumbSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(photo.title.isEmpty ? "Open photo" : "Open \(photo.title)")
        }
    }

    private func caption(for photo: Photo) -> String {
        let date = photo.timestamp.display
        return photos.count > 1 ? "\(index + 1) / \(photos.count) · \(date)" : date
    }

    private func chevron(_ systemName: String, enabled: Bool, action: @escaping () -> Void)
        -> some View
    {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { action() }
        } label: {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: 28, height: thumbSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.25)
        .accessibilityLabel(systemName.contains("left") ? "Previous photo" : "Next photo")
    }
}
