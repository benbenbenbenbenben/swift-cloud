import CloudAWS
import CloudCore
import Foundation

@main
struct aws: AWSProject {
    func build() async throws -> CloudCore.Outputs {
        let instance = AWS.Instance(
            "example-instance",
            args: .init(
                ami: "ami-0634ecbc273c9df53",
                key: .generated
            )
        )
        return [
            "instanceID": instance.instanceId,
            "instancePublicIP": instance.publicIp,
            "instancePublicDNS": instance.dnsName,
        ]
    }
}
