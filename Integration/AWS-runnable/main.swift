import CloudAWS
import CloudCore
import Foundation

@main
struct aws: AWSProject {
    let region: String = "us-east-1"
    func build() async throws -> CloudCore.Outputs {
        let vpc = AWS.VPC.default()
        let firstSubnet = vpc.publicSubnetIds.keyPath("[0]")
        let instance = AWS.Instance(
            "example-instance",
            args: .init(
                ami: "ami-0634ecbc273c9df53",
                key: .imported(
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDlHOrgzwDpMuQflITL0xS8DgQ0ukf4M9eXrwjIL9RfL eddsa-key-20250815"
                ),
                subnetId: "\(firstSubnet)",
                securityGroupId: .new(
                    .init(
                        "example-instance-security-group",
                        ingress: [.ipv4("0.0.0.0/0")],
                        egress: [.ipv4("0.0.0.0/0")]
                    ))
            )
        )
        return [
            "instanceID": instance.instanceId,
            "instancePublicIP": instance.publicIp,
            "instancePublicDNS": instance.dnsName,
        ]
    }
}
