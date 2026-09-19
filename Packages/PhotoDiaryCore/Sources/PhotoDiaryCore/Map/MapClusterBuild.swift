import Foundation

/// Clusters for a viewport, and how far past it they reach (as a
/// fraction of the viewport's span on each side).
public struct MapClusterBuild: Hashable, Sendable {
    public let clusters: [MapCluster]
    public let margin: Double

    public init(clusters: [MapCluster], margin: Double) {
        self.clusters = clusters
        self.margin = margin
    }
}

extension MapClustering {
    /// Pins are built this far past the viewport when the map is
    /// sparse enough: zoomed in and panning around, the next couple of
    /// screens are already in place.
    public static let widestMargin = 2.0

    /// As wide as `widest` allows within `budget` annotations.
    /// Over budget, the clusters farthest from the viewport go first,
    /// but never those within `defaultMargin` of it.
    public static func build(
        pins: [PhotoMapPin],
        in region: MapRegion,
        columns: Int = 6,
        widest: Double = widestMargin,
        budget: Int = annotationBudget
    ) -> MapClusterBuild {
        let all = clusters(pins: pins, in: region, columns: columns, margin: widest)
        guard all.count > budget else {
            return MapClusterBuild(clusters: all, margin: widest)
        }
        let ranked =
            all
            .map { (reach: reach(of: $0, from: region), cluster: $0) }
            .sorted { $0.reach < $1.reach }
        let kept = max(budget, ranked.prefix { $0.reach <= defaultMargin }.count)
        guard kept < ranked.count else {
            return MapClusterBuild(clusters: all, margin: widest)
        }
        // A dropped cluster's pins may sit up to a cell nearer than its
        // centroid, so the area known to be complete ends a cell short.
        let cell = cellSize(for: region.longitudeDelta, columns: columns)
        let slack = cell / min(region.latitudeDelta, region.longitudeDelta)
        return MapClusterBuild(
            clusters: ranked.prefix(kept).map(\.cluster).sorted { $0.id < $1.id },
            margin: max(defaultMargin, ranked[kept].reach - slack)
        )
    }

    /// How far past the viewport's edge a cluster lies, in viewport
    /// spans; negative inside it.
    private static func reach(of cluster: MapCluster, from region: MapRegion) -> Double {
        max(
            abs(cluster.latitude - region.centerLatitude) / region.latitudeDelta,
            abs(cluster.longitude - region.centerLongitude) / region.longitudeDelta
        ) - 0.5
    }
}
