/// The phases every loading screen goes through. `empty` is a
/// successful load with nothing to show, kept apart so the screen can
/// say so instead of rendering a blank list.
enum LoadState<Value> {
    case loading
    case loaded(Value)
    case empty
    case failed(LoadFailure)

    /// Stale-while-revalidate: what's cached shows at once, the fresh
    /// answer replaces it, and a failed refresh keeps the cache. With
    /// nothing cached this is a plain load behind a spinner.
    @MainActor
    static func load(
        cached: () async -> Value?,
        fresh: () async throws -> Value,
        isEmpty: (Value) -> Bool = { _ in false },
        into update: (LoadState) -> Void
    ) async {
        let stale = await cached()
        if let stale {
            update(isEmpty(stale) ? .empty : .loaded(stale))
        } else {
            update(.loading)
        }
        do {
            let value = try await fresh()
            update(isEmpty(value) ? .empty : .loaded(value))
        } catch {
            if stale == nil { update(.failed(LoadFailure(error))) }
        }
    }
}
