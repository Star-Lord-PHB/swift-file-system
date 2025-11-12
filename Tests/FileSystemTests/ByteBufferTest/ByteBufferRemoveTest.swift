import Testing
import SystemPackage
import Foundation
@testable import FileSystem


extension FileSystemTest.ByteBufferTest {

    @Test("Remove At Index")
    func removeAtIndex() async throws {
        
        var data = Data(0 ..< 100)
        var buffer = ByteBuffer(data)

        buffer.remove(at: 50)
        data.remove(at: 50)

        expectEqual(buffer, data)

        buffer.remove(at: 0)
        data.remove(at: 0)

        expectEqual(buffer, data)

        buffer.remove(at: buffer.count - 1)
        data.remove(at: data.count - 1)

        expectEqual(buffer, data)

    }


    @Test("Remove At Range")
    func removeAtRange() async throws {
        
        var data = Data(0 ..< 100)
        var buffer = ByteBuffer(data)

        buffer.removeSubrange(20 ..< 30)
        data.removeSubrange(20 ..< 30)

        expectEqual(buffer, data)

        buffer.removeSubrange(0 ..< 10)
        data.removeSubrange(0 ..< 10)

        expectEqual(buffer, data)

        buffer.removeSubrange(buffer.count - 10 ..< buffer.count)
        data.removeSubrange(data.count - 10 ..< data.count)

        expectEqual(buffer, data)

    }


    @Test("Remove All (Clear Capacity)")
    func removeAllClearCapacity() async throws {
        
        var data = Data(0 ..< 100)
        var buffer = ByteBuffer(data)

        buffer.removeAll()
        data.removeAll()

        expectEqual(buffer, data)
        #expect(buffer.capacity == 0)

    }


    @Test("Remove All (Keep Capacity)")
    func removeAllKeepCapacity() async throws {
        
        var data = Data(0 ..< 100)
        var buffer = ByteBuffer(data)

        let originalCapacity = buffer.capacity

        buffer.removeAll(keepingCapacity: true)
        data.removeAll(keepingCapacity: true)

        expectEqual(buffer, data)
        #expect(buffer.capacity == originalCapacity)

    }


    @Test("Remove Where")
    func removeWhere() async throws {
        
        var data = Data(0 ..< 100)
        var buffer = ByteBuffer(data)

        buffer.removeAll(where: { $0 % 3 == 0 })
        data.removeAll(where: { $0 % 3 == 0 })

        expectEqual(buffer, data)

    }

}