import SystemPackage
import Testing
import SwiftFileSystem



// Shared by the Skip suite and the platform error suites: a traversal is driven with skip requests made at
// chosen elements, and the outcome is compared as a whole with the unskipped traversal of the same tree
// transformed by the skip contract. Sibling order is up to the file system, which is why expectations are
// derived from that baseline instead of being written out.
extension RecursiveSequenceAPITests {

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


        /// Whether this element closes the directory at `dir`: its leaving marker, or the sub-tree error of a
        /// directory that could not be entered.
        func closes(_ dir: FilePath) -> Bool {
            switch self {
                case .leavingDir(let path, _), .subTreeError(let path, _): path == dir
                default: false
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


    /// The elements a traversal yielded, in order, with the transformations the skip contract is stated in.
    struct Traversal: Equatable, Sendable, CustomStringConvertible {

        var elements: [ElementShape]


        init(_ elements: [ElementShape] = []) {
            self.elements = elements
        }


        var isEmpty: Bool { elements.isEmpty }

        func contains(_ element: ElementShape) -> Bool { elements.contains(element) }

        func contains(where predicate: (ElementShape) -> Bool) -> Bool { elements.contains(where: predicate) }

        var description: String { "[\n" + elements.map { "    \($0)" }.joined(separator: "\n") + "\n]" }


        /// This traversal with the region of the directory at `dir` removed: everything after its entry up to
        /// and including its closing element.
        func removingRegion(of dir: FilePath, sourceLocation: SourceLocation = #_sourceLocation) throws -> Traversal {
            let entry = try #require(elements.firstIndex(of: .entry(dir, .directory)), sourceLocation: sourceLocation)
            let closing = try #require(
                elements[(entry + 1)...].firstIndex { $0.closes(dir) },
                sourceLocation: sourceLocation
            )
            return Traversal(Array(elements[...entry]) + Array(elements[(closing + 1)...]))
        }


        /// This traversal cut right after `trigger`, continued with the early leaving marker of the directory at
        /// `dir` and then with everything that follows the real marker of that directory.
        func leavingEarly(
            after trigger: ElementShape,
            dir: FilePath,
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws -> Traversal {
            let triggerIndex = try #require(elements.firstIndex(of: trigger), sourceLocation: sourceLocation)
            let marker = try #require(
                elements[(triggerIndex + 1)...].firstIndex { $0.closes(dir) },
                sourceLocation: sourceLocation
            )
            return Traversal(Array(elements[...triggerIndex]) + [.leavingDir(dir, nil)] + Array(elements[(marker + 1)...]))
        }


        /// This traversal cut right after `trigger`.
        func ending(after trigger: ElementShape, sourceLocation: SourceLocation = #_sourceLocation) throws -> Traversal {
            let triggerIndex = try #require(elements.firstIndex(of: trigger), sourceLocation: sourceLocation)
            return Traversal(Array(elements[...triggerIndex]))
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

        init(after: ElementShape, actions: [SkipAction]) {
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


    /// Runs the traversal to its end, making the requests of `before` ahead of the first `next()` and those of
    /// each trigger right after its element, and returns every element in order. Root errors are thrown; error
    /// elements are returned like any other element. The iterator must stay ended afterwards.
    static func run(
        _ sequence: DirectoryEntryRecursiveSequence,
        before: [SkipAction] = [],
        triggers: [SkipTrigger] = [],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Traversal {

        var iterator = sequence.makeIterator()
        var traversal = Traversal()

        apply(before, to: &iterator)
        while let result = iterator.next() {
            let element = ElementShape(try result.get())
            traversal.elements.append(element)
            for trigger in triggers where trigger.after == element {
                apply(trigger.actions, to: &iterator)
            }
        }
        #expect(iterator.next() == nil, sourceLocation: sourceLocation)

        return traversal

    }

}
