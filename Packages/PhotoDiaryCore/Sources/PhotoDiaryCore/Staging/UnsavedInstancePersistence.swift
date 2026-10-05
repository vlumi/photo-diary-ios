/// A staged launch reads the saved instances (their sessions are what
/// the shots show) but saves nothing back, so the scope it opens is
/// gone at the next ordinary launch.
public struct UnsavedInstancePersistence: InstancePersistence {
    private let base: any InstancePersistence

    public init(_ base: any InstancePersistence) {
        self.base = base
    }

    public func loadInstanceIds() -> [String]? { base.loadInstanceIds() }
    public func saveInstanceIds(_ ids: [String]) {}
    public func loadScope() -> Scope? { base.loadScope() }
    public func saveScope(_ scope: Scope?) {}
}
