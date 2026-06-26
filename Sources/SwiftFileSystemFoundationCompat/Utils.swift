import protocol Foundation.ContiguousBytes



extension ContiguousBytes {
    
    package func withUnsafeBytesTypedThrow<R: ~Copyable, E: Error>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        do {
            var result: R?
            try self.withUnsafeBytes { bufferPtr in
                result = try body(bufferPtr)
            }
            return result!
        } catch let error as E {
            throw error
        } catch {
            fatalError("Expect error of type \(E.self), but got: \(error)")
        }
    }
    
}
