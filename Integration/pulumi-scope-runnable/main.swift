import CloudAWS
import CloudCore
import Foundation

@main
struct scope: AWSProject {
    func build() async throws -> CloudCore.Outputs {
        

        let task = Resource(
            name: "build-targets",
            type: "command:local:Command",
            properties: [
                "create": "swift --version"
            ],
            options: nil,
            context: .current,
        )

        return [
            "stdout": task.output.keyPath("stdout")
        ]
    }
}
