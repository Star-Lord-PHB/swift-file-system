//
//  Thread.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/23.
//

import PlatformCLib


#if canImport(WinSDK)
internal typealias PlatformThreadHandle = HANDLE
#else
internal typealias PlatformThreadHandle = pthread_t
#endif


/// A minimal joinable native thread (pthread / Win32) for the async executor's worker pool.
///
/// Lifecycle contract (the object is not internally synchronized):
/// - `start()` must be called exactly once, and `join()` at most once after it; the caller
///   must order the two calls (same thread, or an external happens-before).
/// - Deallocating a started-but-unjoined `Thread` detaches it: the thread keeps running and
///   the system reclaims its resources when it exits.
final class Thread: @unchecked Sendable {

    private enum LifecycleState {
        case initial(name: String?, task: () -> Void)
        case started(PlatformThreadHandle)
        case terminated
    }

    private var state: LifecycleState


    /// - Parameter name: Debug name applied on the new thread right before `task` runs.
    ///   Linux limits names to 15 bytes (longer ones are truncated); FreeBSD/OpenBSD do not
    ///   expose a naming API through the imported libc, so the name is ignored there.
    init(name: String? = nil, task: sending @escaping () -> Void) {
        self.state = .initial(name: name, task: task)
    }


    deinit {
        guard case .started(let handle) = state else { return }
        #if canImport(WinSDK)
        CloseHandle(handle)
        #else
        pthread_detach(handle)
        #endif
    }


    func start() {
        guard case .initial(let name, let task) = state else {
            preconditionFailure("start() called twice on the same Thread")
        }
        let context = Unmanaged.passRetained(ThreadStartContext(name: name, task: task)).toOpaque()

        #if canImport(WinSDK)

        guard let handle = CreateThread(nil, 0, threadEntryPoint, context, 0, nil) else {
            let code = GetLastError()
            Unmanaged<ThreadStartContext>.fromOpaque(context).release()
            fatalError("CreateThread failed with error \(code)")
        }
        state = .started(handle)

        #else

        #if canImport(Darwin)
        var handle: pthread_t? = nil
        #elseif canImport(Musl) || os(FreeBSD) || os(OpenBSD)
        var handle: pthread_t = nil
        #else
        var handle = pthread_t()
        #endif

        let code = pthread_create(&handle, nil, threadEntryPoint, context)
        guard code == 0 else {
            Unmanaged<ThreadStartContext>.fromOpaque(context).release()
            fatalError("pthread_create failed with error \(code)")
        }

        #if canImport(Darwin)
        state = .started(handle!)
        #else
        state = .started(handle)
        #endif

        #endif
    }


    func join() {
        guard case .started(let handle) = state else {
            preconditionFailure("join() requires a started, not yet joined Thread")
        }

        #if canImport(WinSDK)
        let waitResult = WaitForSingleObject(handle, INFINITE)
        precondition(waitResult == WAIT_OBJECT_0, "WaitForSingleObject failed with error \(GetLastError())")
        CloseHandle(handle)
        #else
        let code = pthread_join(handle, nil)
        precondition(code == 0, "pthread_join failed with error \(code)")
        #endif

        state = .terminated
    }

}



private final class ThreadStartContext {

    let name: String?
    let task: () -> Void

    init(name: String?, task: @escaping () -> Void) {
        self.name = name
        self.task = task
    }

}


#if canImport(WinSDK)
private func threadEntryPoint(_ rawContext: LPVOID?) -> DWORD {
    runThreadStartContext(rawContext.unsafelyUnwrapped)
    return 0
}
#elseif canImport(Darwin)
private func threadEntryPoint(_ rawContext: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    runThreadStartContext(rawContext)
    return nil
}
#else
private func threadEntryPoint(_ rawContext: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    runThreadStartContext(rawContext.unsafelyUnwrapped)
    return nil
}
#endif


private func runThreadStartContext(_ rawContext: UnsafeMutableRawPointer) {
    let context = Unmanaged<ThreadStartContext>.fromOpaque(rawContext).takeRetainedValue()
    if let name = context.name {
        setCurrentThreadName(name)
    }
    context.task()
}


private func setCurrentThreadName(_ name: String) {
    #if canImport(WinSDK)
    name.withCString(encodedAs: UTF16.self) {
        _ = SetThreadDescription(GetCurrentThread(), $0)
    }
    #elseif canImport(Darwin)
    pthread_setname_np(name)
    #elseif os(FreeBSD) || os(OpenBSD)
    // pthread_set_name_np lives in <pthread_np.h>, which the imported libc does not expose.
    #else
    // The kernel rejects names longer than 15 bytes + NUL, so truncate instead of failing.
    withUnsafeTemporaryAllocation(of: CChar.self, capacity: 16) { buffer in
        let terminatorIndex = name.utf8Span.span.withUnsafeBufferPointer { pointer in
            pointer.withMemoryRebound(to: CChar.self) { rebound in
                buffer[..<15].initialize(fromContentsOf: rebound.prefix(15))
            }
        }
        buffer[terminatorIndex] = 0
        _ = pthread_setname_current(buffer.baseAddress.unsafelyUnwrapped)
    }
    #endif
}
