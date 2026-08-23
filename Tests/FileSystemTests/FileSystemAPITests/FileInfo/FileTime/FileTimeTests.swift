import Foundation
import PlatformCLib
import Testing
import SwiftFileSystem
import SwiftFileSystemFoundationCompat



extension FileInfoAPITests {

    @Suite("File time")
    struct FileTimeTests {}

}



extension FileInfoAPITests.FileTimeTests {

    @Test
    func `Native file time conversion preserves platform precision`() {

        #if canImport(WinSDK)
        let hundredNanoseconds = 0x0123_4567_89AB_CDEF as UInt64
        let nativeTime = FILETIME(
            dwLowDateTime: DWORD(hundredNanoseconds & 0xFFFF_FFFF),
            dwHighDateTime: DWORD(hundredNanoseconds >> 32)
        )
        let expectedSeconds = Int(hundredNanoseconds / 10_000_000)
        let expectedNanoseconds = Int(hundredNanoseconds % 10_000_000) * 100
        #else
        let nativeTime = PlatformInteropTypes.FileTime(
            tv_sec: 1_765_432_100,
            tv_nsec: 123_456_789
        )
        let expectedSeconds = 1_765_432_100
        let expectedNanoseconds = 123_456_789
        #endif

        let time = FileTimeSpec(platformFileTime: nativeTime)
        let convertedNativeTime = time.platformFileTime

        #expect(time.seconds == expectedSeconds)
        #expect(time.nanoseconds == expectedNanoseconds)
        #if canImport(WinSDK)
        #expect(convertedNativeTime.dwLowDateTime == nativeTime.dwLowDateTime)
        #expect(convertedNativeTime.dwHighDateTime == nativeTime.dwHighDateTime)
        #else
        #expect(convertedNativeTime.tv_sec == nativeTime.tv_sec)
        #expect(convertedNativeTime.tv_nsec == nativeTime.tv_nsec)
        #endif

    }


    @Test
    func `FileTimes maps native fields including creation`() {

        let expectedAccess = FileTimeSpec(seconds: 1_765_432_101, nanoseconds: 100)
        let expectedModification = FileTimeSpec(seconds: 1_765_432_102, nanoseconds: 200)
        let expectedChange = FileTimeSpec(seconds: 1_765_432_103, nanoseconds: 300)
        let expectedCreation = FileTimeSpec(seconds: 1_765_432_104, nanoseconds: 400)

        let times = FileTimes(
            lastAccess: expectedAccess.platformFileTime,
            lastModification: expectedModification.platformFileTime,
            lastChange: expectedChange.platformFileTime,
            creation: expectedCreation.platformFileTime
        )

        #expect(times.lastAccess == expectedAccess)
        #expect(times.lastModification == expectedModification)
        #expect(times.lastChange == expectedChange)
        #expect(times.creation == expectedCreation)

    }


    @Test
    func `FileTimes preserves absent creation time`() {

        let access = FileTimeSpec(seconds: 1, nanoseconds: 100).platformFileTime
        let modification = FileTimeSpec(seconds: 2, nanoseconds: 200).platformFileTime
        let change = FileTimeSpec(seconds: 3, nanoseconds: 300).platformFileTime

        let times = FileTimes(
            lastAccess: access,
            lastModification: modification,
            lastChange: change,
            creation: nil
        )

        #expect(times.creation == nil)

    }


    @Test
    func `Date conversion uses the platform epoch and round trips`() {

        let date = Date(timeIntervalSince1970: 1_765_432_100.125)

        let time = FileTimeSpec(from: date)

        #if canImport(WinSDK)
        #expect(time.seconds == 13_409_905_700)
        #else
        #expect(time.seconds == 1_765_432_100)
        #endif
        #expect(time.nanoseconds == 125_000_000)
        #expect(abs(time.date.timeIntervalSince(date)) < 0.000_001)

    }


    #if canImport(WinSDK)
    @Test
    func `FILETIME conversion truncates to 100-nanosecond precision`() {

        let time = FileTimeSpec(
            seconds: 1_765_432_100,
            nanoseconds: 123_456_789
        )

        let timeAtFileTimePrecision = FileTimeSpec(
            platformFileTime: time.platformFileTime
        )

        #expect(timeAtFileTimePrecision.seconds == time.seconds)
        #expect(timeAtFileTimePrecision.nanoseconds == 123_456_700)

    }


    @Test
    func `LARGE_INTEGER conversion preserves high and low bits`() {

        let hundredNanoseconds = 0x0123_4567_89AB_CDEF as UInt64
        let lowBits = DWORD(hundredNanoseconds & 0xFFFF_FFFF)
        let highBits = DWORD(hundredNanoseconds >> 32)
        var largeInteger = LARGE_INTEGER()
        largeInteger.LowPart = lowBits
        largeInteger.HighPart = LONG(bitPattern: highBits)
        let expected = FileTimeSpec(
            seconds: Int(hundredNanoseconds / 10_000_000),
            nanoseconds: Int(hundredNanoseconds % 10_000_000) * 100
        )

        let timeSpecFromLargeInteger = FileTimeSpec(platformFileTime: largeInteger)
        let fileTimeFromLargeInteger = FILETIME(largeInteger: largeInteger)

        #expect(timeSpecFromLargeInteger == expected)
        #expect(fileTimeFromLargeInteger.dwLowDateTime == lowBits)
        #expect(fileTimeFromLargeInteger.dwHighDateTime == highBits)

    }
    #endif

}
