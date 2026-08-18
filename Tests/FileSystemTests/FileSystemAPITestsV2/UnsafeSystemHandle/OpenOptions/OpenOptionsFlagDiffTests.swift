import Testing
import SwiftFileSystem


private typealias FlagDiff =
    UnsafeSystemHandle.OpenOptions.NativeFlagDiff<UnsafeSystemHandle.OpenOptions.NativeOpenFlag>



// The insert/remove invariant: the two bit sets stay disjoint, with the later mutation clearing
// the overlapping bits from the other side, so applying a diff never depends on mutation order.
extension UnsafeSystemHandleAPITests.OpenOptionsTests {

    @Test
    func `Insert clears the overlapping removed bits`() {

        var diff = FlagDiff(rawRemoved: 0b0110)

        diff.insert(0b0011)

        #expect(diff.inserted == 0b0011)
        #expect(diff.removed == 0b0100)

    }


    @Test
    func `Remove clears the overlapping inserted bits`() {

        var diff = FlagDiff(rawInserted: 0b0011)

        diff.remove(0b0110)

        #expect(diff.inserted == 0b0001)
        #expect(diff.removed == 0b0110)

    }


    @Test
    func `Initializer resolves an overlap in favor of inserted`() {

        let diff = FlagDiff(rawInserted: 0b0011, rawRemoved: 0b0110)

        #expect(diff.inserted == 0b0011)
        #expect(diff.removed == 0b0100)

    }

}
