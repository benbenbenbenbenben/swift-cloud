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
                key: .imported("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDlHOrgzwDpMuQflITL0xS8DgQ0ukf4M9eXrwjIL9RfL eddsa-key-20250815"),
                securityGroupId: .new
            )
        )
        return [
            "instanceID": instance.instanceId,
            "instancePublicIP": instance.publicIp,
            "instancePublicDNS": instance.dnsName,
        ]
    }
}
