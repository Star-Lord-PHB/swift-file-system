import Testing


struct TestCancellationError: Error {
    let sourceLocation: SourceLocation
    fileprivate init(sourceLocation: SourceLocation) {
        self.sourceLocation = sourceLocation
    }
}


#if swift(<6.3)
extension Test {
    static func cancel(_ comment: Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation) throws -> Never {
        throw TestCancellationError(sourceLocation: sourceLocation)
    }
}
#endif


struct CatchTestCancellationSuite: TestTrait, SuiteTrait {

    struct TestScopeProvider: TestScoping {

        func provideScope(for test: Test, testCase: Test.Case?, performing: () async throws -> Void) async throws {
            do {
                try await performing()
            } catch let error as TestCancellationError {
                #if swift(>=6.3)
                Issue.record(
                    "TestCancellationError detected on swift 6.3+. Please use `Test.cancel()` for test cancellation", 
                    severity: .warning, 
                    sourceLocation: error.sourceLocation
                )
                #endif
            }
        }

    }

    var isRecursive: Bool { true }

    func scopeProvider(
        for test: Test,
        testCase: Test.Case?
    ) -> TestScopeProvider? {
        return .init()
    }

}



extension TestTrait where Self == CatchTestCancellationSuite {
    static var catchTestCancellation: CatchTestCancellationSuite { .init() }
}



extension SuiteTrait where Self == CatchTestCancellationSuite {
    static var catchTestCancellation: CatchTestCancellationSuite { .init() }
}
