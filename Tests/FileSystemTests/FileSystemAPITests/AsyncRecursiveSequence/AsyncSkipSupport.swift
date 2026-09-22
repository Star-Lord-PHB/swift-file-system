import SystemPackage
import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



// NOTE: `SwiftFileSystem` is imported for the synchronous `DirectoryEntryRecursiveSequence` oracle only: the
// skip contract is pinned by the synchronous group, and what this group pins is that the batched iterator
// yields the same elements for every batch size, wherever the skipped region falls relative to the batch
// boundaries. A traversal is driven with skip requests made at chosen elements, on both iterators alike.
extension AsyncRecursiveSequenceAPITests {

    /// A traversal element reduced to what the skip contract is stated in terms of: the case, the path, the
    /// entry kind and the error kind.
    enum ElementShape: Equatable, Sendable, CustomStringConvertible {

        case entry(FilePath, FileKind)
        case leavingDir(FilePath, PlatformErrorKind?)
        case entryError(FilePath, PlatformErrorKind)
        case subTreeError(FilePath, PlatformErrorKind)


        init(_ element: DirectoryEntryRecursiveSequenceElement) {
            self = switch element {
                case .entry(let entry):                  .entry(entry.path, entry.type)
                case .leavingDir(let path, let error):   .leavingDir(path, error?.kind)
                case .entryError(let path, let error):   .entryError(path, error.kind)
                case .subTreeError(let path, let error): .subTreeError(path, error.kind)
            }
        }


        var path: FilePath {
            switch self {
                case .entry(let path, _):        path
                case .leavingDir(let path, _):   path
                case .entryError(let path, _):   path
                case .subTreeError(let path, _): path
            }
        }


        var description: String {
            switch self {
                case .entry(let path, let kind):        "entry(\(path), \(kind))"
                case .leavingDir(let path, let kind):   "leavingDir(\(path), \(kind.map { "\($0)" } ?? "nil"))"
                case .entryError(let path, let kind):   "entryError(\(path), \(kind))"
                case .subTreeError(let path, let kind): "subTreeError(\(path), \(kind))"
            }
        }

    }


    enum SkipAction: Sendable {
        case skipDescendants
        case skipCurrentDir
    }


    /// Skip requests made, in order, right after the element equal to `after` has been returned.
    struct SkipTrigger: Sendable {

        let after: ElementShape
        let actions: [SkipAction]

        init(after: ElementShape, _ actions: SkipAction...) {
            self.after = after
            self.actions = actions
        }

    }


    static func apply(_ actions: [SkipAction], to iterator: inout DirectoryEntryRecursiveSequence.Iterator) {
        for action in actions {
            switch action {
                case .skipDescendants: iterator.skipDescendants()
                case .skipCurrentDir:  iterator.skipCurrentDir()
            }
        }
    }


    static func apply(_ actions: [SkipAction], to iterator: inout AsyncDirectoryEntryRecursiveSequence.AsyncIterator) {
        for action in actions {
            switch action {
                case .skipDescendants: iterator.skipDescendants()
                case .skipCurrentDir:  iterator.skipCurrentDir()
            }
        }
    }


    /// The oracle: the synchronous traversal driven with the same requests, run to its end.
    static func runSync(
        _ sequence: DirectoryEntryRecursiveSequence,
        before: [SkipAction] = [],
        triggers: [SkipTrigger] = []
    ) throws -> [ElementShape] {

        var iterator = sequence.makeIterator()
        var elements = [ElementShape]()

        apply(before, to: &iterator)
        while let result = iterator.next() {
            let element = ElementShape(try result.get())
            elements.append(element)
            for trigger in triggers where trigger.after == element {
                apply(trigger.actions, to: &iterator)
            }
        }

        return elements

    }


    /// Runs the async traversal to its end, making the requests of `before` ahead of the first `next()` and
    /// those of each trigger right after its element, and returns every element in order. The iterator must
    /// stay ended afterwards.
    static func run(
        _ sequence: AsyncDirectoryEntryRecursiveSequence,
        before: [SkipAction] = [],
        triggers: [SkipTrigger] = [],
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> [ElementShape] {

        var iterator = sequence.makeAsyncIterator()
        var elements = [ElementShape]()

        apply(before, to: &iterator)
        while let element = try await iterator.next() {
            let shape = ElementShape(element)
            elements.append(shape)
            for trigger in triggers where trigger.after == shape {
                apply(trigger.actions, to: &iterator)
            }
        }
        #expect(try await iterator.next() == nil, sourceLocation: sourceLocation)

        return elements

    }

}
