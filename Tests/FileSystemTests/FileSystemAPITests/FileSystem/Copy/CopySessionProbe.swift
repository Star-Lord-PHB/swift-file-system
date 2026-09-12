import SystemPackage
import Testing
import FileSystemCore

@testable import SwiftFileSystem



// Helpers for the suites that drive `CopyItemHandler` one `copyStep()` at a time.
extension FileSystemAPITests.CopyTests {

    typealias CopyErrorStrategy = FileOperationOptions.RecursiveCopyErrorStrategyProtocol


    /// The shape of a handler's state between two steps, without the contexts themselves.
    enum SessionState: Equatable {
        case ready
        case copying(hasDirectory: Bool, hasFile: Bool)
        case ended(cancelled: Bool)
    }


    static func sessionState<S: CopyErrorStrategy>(
        of handler: borrowing CopyItemHandler<S>
    ) -> SessionState? {
        // A `~Copyable` enum cannot be matched with a case label of several patterns, so every
        // combination gets its own case.
        switch handler.state {
            case .none: nil
            case .ready: .ready
            case .copying(.none, .none): .copying(hasDirectory: false, hasFile: false)
            case .copying(.none, .some): .copying(hasDirectory: false, hasFile: true)
            case .copying(.some, .none): .copying(hasDirectory: true, hasFile: false)
            case .copying(.some, .some): .copying(hasDirectory: true, hasFile: true)
            case .ended(let cancelled): .ended(cancelled: cancelled)
        }
    }


    #if canImport(Glibc) || canImport(Musl)
    /// The mechanism the file copy in progress is using, or nil while no file is in progress.
    static func contentMechanism<S: CopyErrorStrategy>(
        of handler: borrowing CopyItemHandler<S>
    ) -> CopyItemHandler<S>.CopyFileContentContext.ContentCopyMechanism? {
        switch handler.state {
            case .copying(_, .some(let context)): context.mechanism
            default: nil
        }
    }
    #endif


    /// Steps `handler` until `condition` holds and returns the number of steps taken; fails the
    /// test if the copy completes or `stepLimit` steps pass first.
    @discardableResult
    static func step<S: CopyErrorStrategy>(
        _ handler: inout CopyItemHandler<S>,
        until condition: (borrowing CopyItemHandler<S>) throws -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Int {
        var steps = 0
        while try !condition(handler) {
            try #require(
                steps < stepLimit,
                "The copy did not reach the expected state within \(stepLimit) steps",
                sourceLocation: sourceLocation
            )
            let result = handler.copyStep()
            steps += 1
            try #require(
                result == .paused,
                "The copy completed before reaching the expected state",
                sourceLocation: sourceLocation
            )
        }
        return steps
    }


    /// Steps `handler` to completion and returns the number of steps taken, counting the one
    /// that completed the copy.
    @discardableResult
    static func stepToCompletion<S: CopyErrorStrategy>(
        _ handler: inout CopyItemHandler<S>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Int {
        var steps = 1
        while handler.copyStep() == .paused {
            steps += 1
            try #require(
                steps <= stepLimit,
                "The copy did not complete within \(stepLimit) steps",
                sourceLocation: sourceLocation
            )
        }
        return steps
    }


    private static let stepLimit = 10_000

}
