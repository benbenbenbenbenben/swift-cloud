// Swift
//
// Sources/CloudAWS/Components/Instance.swift
//
// Skeleton for an AWS EC2 Instance component for the swift-cloud project.
// This file intentionally contains TODOs where Pulumi resource creation and wiring should be implemented.
// Follow existing component patterns in Sources/CloudAWS/Components/* for coding conventions.

import CloudCore
import Foundation

extension AWS {
    public struct InstanceVolume: Sendable {
        public let deviceName: String
        public let sizeGB: Int
        public let volumeType: String?  // e.g., "gp3"
        public let deleteOnTermination: Bool

        public init(deviceName: String, sizeGB: Int, volumeType: String? = nil, deleteOnTermination: Bool = true) {
            self.deviceName = deviceName
            self.sizeGB = sizeGB
            self.volumeType = volumeType
            self.deleteOnTermination = deleteOnTermination
        }
    }

    public enum InstanceKeyPair: Sendable {
        case named(String)
        case generated
    }

    /// Arguments used to configure an EC2 Instance component.
    public struct InstanceArgs: Sendable {
        public let ami: String?
        public let instanceType: String
        public let key: InstanceKeyPair?
        public let subnetId: String?
        public let securityGroupIds: [String]?
        public let userData: String?
        public let volumes: [InstanceVolume]?
        public let iamRoleArn: String?
        public let tags: [String: String]?
        public let publicIP: Bool
        public let associateElasticIP: Bool

        public init(
            ami: String? = nil,
            instanceType: String = "t3.micro",
            key: InstanceKeyPair? = nil,
            subnetId: String? = nil,
            securityGroupIds: [String]? = nil,
            userData: String? = nil,
            volumes: [InstanceVolume]? = nil,
            iamRoleArn: String? = nil,
            tags: [String: String]? = nil,
            publicIP: Bool = false,
            associateElasticIP: Bool = false
        ) {
            self.ami = ami
            self.instanceType = instanceType
            self.key = key
            self.subnetId = subnetId
            self.securityGroupIds = securityGroupIds
            self.userData = userData
            self.volumes = volumes
            self.iamRoleArn = iamRoleArn
            self.tags = tags
            self.publicIP = publicIP
            self.associateElasticIP = associateElasticIP
        }
    }

    /// EC2 Instance component skeleton. Conforms to the project's component pattern.
    /// TODO: replace "Any" / placeholder types with concrete CloudCore/CloudAWS types as appropriate.
    public struct Instance: AWSComponent {
        // Public outputs
        public let arn: Output<String>
        public let instanceId: Output<String>
        public let publicIp: Output<String>
        public let privateIp: Output<String>
        public let dnsName: Output<String>

        // Internal references to Pulumi resources (concrete types)
        private let instanceResource: Resource
        private var eipResource: Resource? = nil
        private var volumeResources: [Resource] = []
        private var networkInterface: Resource? = nil

        public var name: Output<String> {
            instanceResource.name
        }
        public let args: InstanceArgs

        /// Initialize the component and create Pulumi resources.
        public init(_ name: String, args: InstanceArgs = InstanceArgs()) {
            self.args = args

            // Validation rules
            precondition(
                !(args.associateElasticIP && !args.publicIP),
                "associateElasticIP requires publicIP == true")

            // Resolve AMI: use args.ami if provided. If not provided, a helper like `AWS.getAmi(...)` is expected.
            // There is currently no AMI helper in the repository; fail with a clear message so callers add one or provide ami.
            let ami = args.ami ?? "ami-0de716d6197524dd9"  // TODO: lookup latest?

            // If volumes are requested we require a subnetId so we can determine availabilityZone for the volumes.
            if let vols = args.volumes, !vols.isEmpty {
                precondition(
                    args.subnetId != nil, "Creating EBS volumes requires subnetId to determine the availability zone")
            }

            // If subnetId provided we may need its availability zone for volumes.
            let subnetInfo: Output<AWS.GetSubnet>? = args.subnetId.map { id in
                // Use existing helper AWS.getSubnet to fetch availabilityZone — referenced here.
                AWS.getSubnet(id)
            }

            // Logical names
            let instanceLogicalName = "\(name)-instance"
            let nicLogicalName = "\(name)-nic"

            // Optionally create a NetworkInterface when explicit security groups are provided
            // or when an Elastic IP must be associated to a specific interface.
            var nicResource: Resource? = nil
            if args.securityGroupIds != nil || args.associateElasticIP {
                nicResource = Resource(
                    name: nicLogicalName,
                    type: "aws:ec2:NetworkInterface",
                    properties: [
                        "subnetId": args.subnetId,
                        "securityGroups": args.securityGroupIds,
                        "description": "\(instanceLogicalName)-nic",
                    ],
                    options: nil,
                    context: .current
                )
                networkInterface = nicResource!
            }

            // Build instance properties.
            var instanceProperties: [String: AnyEncodable?] = [
                "ami": .init(ami),
                "instanceType": .init(args.instanceType),
                "keyName": .init(args.key),
                "userData": .init(args.userData),
                "tags": .init(args.tags),
            ]

            // When a NIC is created, attach it to the instance via networkInterfaces block.
            if let nic = nicResource {
                instanceProperties["networkInterfaces"] = [
                    ["networkInterfaceId": nic.output]
                ]
                // Do not set subnetId or vpcSecurityGroupIds when using a network interface.
                instanceProperties["subnetId"] = nil
            } else {
                instanceProperties["subnetId"] = .init(args.subnetId)
                instanceProperties["vpcSecurityGroupIds"] = .init(args.securityGroupIds)
            }

            // Attach IAM instance profile if an IAM role ARN is provided.
            instanceProperties["iamInstanceProfile"] = args.iamRoleArn.map { arn in
                // Using ARN directly here; a helper could convert role ARN to instance profile name if required.
                ["arn": arn]
            }

            // Create the EC2 Instance resource.
            instanceResource = Resource(
                name: instanceLogicalName,
                type: "aws:ec2:Instance",
                properties: .init(instanceProperties),
                options: nil,
                context: .current
            )

            // Create and attach EBS volumes (if any)
            var createdVolumes: [Resource] = []
            if let vols = args.volumes {
                for (j, vol) in vols.enumerated() {
                    let volName = "\(name)-volume-\(j)"
                    // Build volume properties, including availabilityZone when subnetInfo is present.
                    var volProps: [String: AnyEncodable?] = [
                        "size": .init(vol.sizeGB),
                        "type": .init(vol.volumeType),
                    ]
                    if let subnetInfo = subnetInfo {
                        volProps["availabilityZone"] = .init(subnetInfo.keyPath("availabilityZone"))
                    }

                    let volumeResource = Resource(
                        name: volName,
                        type: "aws:ec2:Volume",
                        properties: .init(volProps),
                        options: nil,
                        context: .current
                    )
                    createdVolumes.append(volumeResource)

                    // Attach volume to instance
                    let attachName = "\(name)-volume-attach-\(j)"
                    let attachProps: [String: AnyEncodable?] = [
                        "deviceName": .init(vol.deviceName),
                        "volumeId": .init(volumeResource.output.keyPath("id")),
                        "instanceId": .init(instanceResource.output.keyPath("id")),
                        "deleteOnTermination": .init(vol.deleteOnTermination),
                    ]
                    _ = Resource(
                        name: attachName,
                        type: "aws:ec2:VolumeAttachment",
                        properties: .init(attachProps),
                        options: .dependsOn([volumeResource, instanceResource]),
                        context: .current
                    )
                }
            }

            // Create Elastic IP and association if requested (independent of volumes)
            var createdEip: Resource? = nil
            if args.publicIP && args.associateElasticIP {
                let eip = Resource(
                    name: "\(name)-eip",
                    type: "aws:ec2:Eip",
                    properties: .init(["vpc": .init(true)]),
                    options: nil,
                    context: .current
                )
                createdEip = eip

                // Association properties must be AnyEncodable-wrapped
                var assocPropsEnc: [String: AnyEncodable?] = [
                    "allocationId": .init(eip.output.keyPath("allocationId"))
                ]
                if let nic = nicResource {
                    assocPropsEnc["networkInterfaceId"] = .init(nic.output.keyPath("id"))
                } else {
                    assocPropsEnc["instanceId"] = .init(instanceResource.output.keyPath("id"))
                }

                _ = Resource(
                    name: "\(name)-eip-assoc",
                    type: "aws:ec2:EipAssociation",
                    properties: .init(assocPropsEnc),
                    options: .dependsOn([eip, instanceResource]),
                    context: .current
                )
            }

            // Assign stored properties
            self.volumeResources = createdVolumes
            self.eipResource = createdEip
            self.networkInterface = nicResource

            // Collect outputs.
            self.instanceId = instanceResource.id
            self.arn = AWS.getARN(instanceResource).arn
            if args.publicIP && args.associateElasticIP, let eip = createdEip {
                self.publicIp = eip.output.keyPath("publicIp")
            } else {
                self.publicIp = instanceResource.output.keyPath("publicIp")
            }
            self.privateIp = instanceResource.output.keyPath("privateIp")
            self.dnsName = instanceResource.output.keyPath("publicDns")
        }

        // Expose a concise summary for other components
        public func outputs() -> [String: Any] {
            return [
                "instanceId": instanceId,
                "arns": arn,
                "publicIps": publicIp,
                "privateIps": privateIp,
                "dnsNames": dnsName,
            ]
        }
    }

    // Example usage (to show expected consumer API):
    // This snippet demonstrates how a project would instantiate the component.
    // DO NOT run this code here — it's an example for implementers.
    /*
    let webInstance = InstanceComponent(
        name: "web-server",
        args: InstanceArgs(
            ami: "ami-0123456789abcdef0", // or leave nil to use AMI helper
            instanceType: "t3.micro",
            keyName: "my-keypair",
            subnetId: "subnet-12345",
            securityGroupIds: ["sg-12345"],
            userData: "#!/bin/bash\necho hello > /var/tmp/ok",
            volumes: [InstanceVolume(deviceName: "/dev/xvdb", sizeGB: 20)],
            iamRoleArn: "arn:aws:iam::123456789012:role/InstanceRole",
            tags: ["Name": "web-server"],
            publicIP: true,
            associateElasticIP: false
        ),
        provider: AWSProvider.shared
    )
    print(webInstance.outputs())
    */
}
