#if canImport(WinSDK)

import Testing


@Suite("WindowsAccessChecker", .executionGroup(.default), .catchTestCancellation)
struct WindowsAccessCheckerTests {}

#endif
