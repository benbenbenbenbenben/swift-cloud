import Testing

@testable import CloudCore
@testable import CloudAWS

@Suite("Project Tests")
struct ProjectTests {
    struct TestProject: Project {
        func build() async throws -> CloudCore.Outputs {
            let _ = AWS.Instance("test-instance")
            return [:]
        }
    }

    @Test("Build context")
    func buildContext() async throws {
        let project = TestProject()
        let context = Context(
            stage: "testing",
            project: project,
            package: .init(name: "test"),
            store: .init(),
            builder: .init()
        )
        #expect(context.stage == "testing")
    }
}
