import Foundation

extension AWS {
    public struct DefaultSubnet: AWSComponent {
        public var name: Output<String> {
            resource.name
        }

        public let resource: Resource

        public init(
            region: String = "us-east-1",
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            resource = Resource(
                name: "default-subnet",
                type: "aws:ec2:DefaultSubnet",
                properties: [
                    // "assignIpv6AddressOnCreation": false,
                    // "availabilityZone": "us-east-1a",
                    // "customerOwnedIpv4Pool": "string",
                    // "enableDns64": false,
                    // "enableResourceNameDnsARecordOnLaunch": false,
                    // "enableResourceNameDnsAaaaRecordOnLaunch": false,
                    // "forceDestroy": false,
                    // "ipv6CidrBlock": "string",
                    // "ipv6Native": false,
                    // "mapCustomerOwnedIpOnLaunch": false,
                    // "mapPublicIpOnLaunch": false,
                    // "privateDnsHostnameTypeOnLaunch": "string",
                    // "region": region,
                    // "tags": [],
                ],
                options: options,
                context: context,
            )
        }
    }
}