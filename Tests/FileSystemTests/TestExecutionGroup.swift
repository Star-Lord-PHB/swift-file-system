import Foundation
import Testing


/// The execution group a test process runs.
///
/// Exactly one group executes per process, selected by the `TEST_EXECUTION_GROUP` environment
/// variable (its value is a case's raw value; unset selects `.default`). Suites declare their
/// group with the `.executionGroup(_:)` trait and are skipped in any other group's run, so
/// groups whose measurements cannot tolerate in-process concurrency (such as
/// `.resourceLifetime`) never run alongside the regular concurrent suites.
enum TestExecutionGroup: String {

    /// The regular concurrent test run.
    case `default`

    /// Process-exclusive run of the ResourceLifetime suite, whose process-wide resource
    /// counting cannot tolerate concurrently running tests.
    case resourceLifetime


    static let environmentVariableName: String = "TEST_EXECUTION_GROUP"


    /// The group selected for the current process.
    static let current: TestExecutionGroup = {
        guard let value = ProcessInfo.processInfo.environment[environmentVariableName] else {
            return .default
        }
        guard let group = TestExecutionGroup(rawValue: value) else {
            preconditionFailure("Unknown \(environmentVariableName) value: \(value)")
        }
        return group
    }()

}



extension Trait where Self == ConditionTrait {

    /// Declares the execution group a top-level suite belongs to.
    ///
    /// Every top-level suite must declare its group (alongside `.catchTestCancellation`);
    /// the suite only runs when the process-wide ``TestExecutionGroup/current`` matches.
    static func executionGroup(_ group: TestExecutionGroup) -> Self {
        .enabled(
            if: TestExecutionGroup.current == group,
            "The suite belongs to the '\(group.rawValue)' execution group"
        )
    }

}
