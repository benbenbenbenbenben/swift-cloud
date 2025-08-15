extension AWS {
    public struct KeyPair: AWSComponent {
        internal let key: Resource

        public var name: Output<String> {
            key.name
        }

        public var id: Output<String> {
            key.id
        }

        /// Create or reference an EC2 Key Pair.
        /// - Parameters:
        ///   - name: logical name for the key resource
        ///   - publicKey: optional public key material to import
        ///   - existingId: optional existing key id to reference an external key
        ///   - options: resource options passed to underlying Resource
        ///   - context: context to register resource in
        public init(
            _ name: String,
            publicKey: String? = nil,
            existingId: String? = nil,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            var props: [String: AnyEncodable?]? = nil
            if let publicKey = publicKey {
                props = ["publicKey": .init(publicKey)]
            }

            key = Resource(
                name: name,
                type: "aws:ec2:KeyPair",
                properties: props.map { .init($0) },
                options: options,
                context: context,
                existingId: existingId
            )
        }
    }
}