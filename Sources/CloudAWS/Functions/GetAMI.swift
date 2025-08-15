// Swift
//
// Sources/CloudAWS/Functions/GetAMI.swift
//
// Helper to lookup an AMI for AWS EC2 instances.
// Wraps the Pulumi lookup function "aws:ec2:getAmi".
// Callers can provide name, owners, filters, or rely on callers to pass an AMI id.
// TODO: expand filters typing and additional fields as needed.

extension AWS {
    public struct GetAMI {
        public let id: String
        public let name: String?
        public let description: String?
        public let owners: [String]?
    }

    /// Lookup an AMI. If `name` is provided it will be used; otherwise owners/filters can be provided.
    /// This wraps the Pulumi function "aws:ec2:getAmi".
    public static func getAmi(
        name: (any Input<String>)? = nil,
        owners: (any Input<[String]>)? = nil,
        filters: [String: Any]? = nil,
        mostRecent: Bool = true
    ) -> Output<GetAMI> {
        var arguments: [String: Any] = ["mostRecent": mostRecent]
        if let name = name { arguments["name"] = name }
        if let owners = owners { arguments["owners"] = owners }
        if let filters = filters { arguments["filters"] = filters }

        // Variable name: include provided name when available for traceability.
        let varName: String
        if name != nil {
            varName = "get-ami-\(String(describing: name!))"
        } else {
            varName = "get-ami"
        }

        let variable = Variable<GetAMI>.invoke(
            name: varName,
            function: "aws:ec2:getAmi",
            arguments: arguments
        )
        return variable.output
    }
}