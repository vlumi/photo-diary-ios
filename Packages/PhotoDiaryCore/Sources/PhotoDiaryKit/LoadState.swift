/// The phases every loading screen goes through. `empty` is a
/// successful load with nothing to show, kept apart so the screen can
/// say so instead of rendering a blank list.
enum LoadState<Value> {
    case loading
    case loaded(Value)
    case empty
    case failed(LoadFailure)
}
