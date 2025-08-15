import CloudCore
import Foundation
import SotoCore

extension AWS {
    public final class Home: HomeProvider {
    private let client: AWSClient
    private let sts: STS
    private let s3: S3

        public init(region: String = "us-east-1") {
            self.client = .init(credentialProvider: Self.credentialProvider())
            self.s3 = .init(client: client, region: .init(rawValue: region))
            self.sts = .init(client: client)
        }

        deinit {
            try? client.syncShutdown()
        }

        public func bootstrap(with context: Context) async throws {
            let bucketName = try await s3BucketName()
            _ = try await ensureBucketExists(bucketName)
        }

        public func putItem<T: HomeProviderItem>(_ item: T, fileName: String, with context: Context) async throws {
            let data = try JSONEncoder().encode(item)
            let bytes = ByteBuffer(data: data)
            let bucketName = try await s3BucketName()
            let key = contextualFileName(fileName, with: context)
            _ = try await s3.putObject(.init(body: .init(buffer: bytes), bucket: bucketName, key: key))
        }

        public func getItem<T: HomeProviderItem>(fileName: String, with context: Context) async throws -> T {
            let bucketName = try await s3BucketName()
            let key = contextualFileName(fileName, with: context)
            let response = try await s3.getObject(.init(bucket: bucketName, key: key))
            let data = try await response.body.collect(upTo: 1024 * 1024)
            return try JSONDecoder().decode(T.self, from: data)
        }
    }
}

extension AWS.Home {
    private func s3BucketName() async throws -> String {
        let account = try await awsAccountId()
        return "swift-cloud-assets-\(account)"
    }

    private func ensureBucketExists(_ bucketName: String) async throws {
        do {
            _ = try await s3.createBucket(.init(bucket: bucketName))
        } catch {
            // Some S3 errors (like PermanentRedirect) are returned as a generic AWSErrorType
            // rather than the generated S3ErrorType. Check for that first.
            if let awsErr = error as? AWSErrorType, awsErr.errorCode == "PermanentRedirect" {
                // Attempt to discover the bucket region and assume the bucket exists there.
                do {
                    let loc: S3.GetBucketLocationOutput = try await client.execute(
                        operation: "GetBucketLocation",
                        path: "/{Bucket}?location",
                        httpMethod: .GET,
                        serviceConfig: s3.config,
                        input: S3.GetBucketLocationRequest(bucket: bucketName),
                        logger: AWSClient.loggingDisabled
                    )

                    var bucketRegion = loc.locationConstraint?.rawValue ?? "us-east-1"
                    // Historical alias: "EU" maps to eu-west-1
                    if bucketRegion == "EU" { bucketRegion = "eu-west-1" }

                    // Create a temporary S3 client for any subsequent operations (no mutation needed)
                    let _ = S3(client: client, region: .init(rawValue: bucketRegion))
                    return
                } catch {
                    // If we can't discover the bucket location, assume it exists and continue.
                    return
                }
            }

            // Otherwise, if it's a typed S3 error, handle known cases.
            if let s3Err = error as? S3ErrorType {
                switch s3Err {
                case .bucketAlreadyOwnedByYou:
                    return
                case .bucketAlreadyExists:
                    throw s3Err
                default:
                    throw s3Err
                }
            }

            // Unknown error - propagate
            throw error
        }
    }
}

extension AWS.Home {
    public enum Error: Swift.Error {
        case invalidAccount
    }

    private func awsAccountId() async throws -> String {
        let response = try await sts.getCallerIdentity()
        guard let account = response.account else {
            throw Error.invalidAccount
        }
        return account
    }

    private static func credentialProvider() -> CredentialProviderFactory {
        let env = Context.environment
        if let accessKey = env["AWS_ACCESS_KEY_ID"], let secret = env["AWS_SECRET_ACCESS_KEY"] {
            let sessionToken = env["AWS_SESSION_TOKEN"]
            return .static(accessKeyId: accessKey, secretAccessKey: secret, sessionToken: sessionToken)
        }
        return .default
    }
}

extension HomeProvider where Self == AWS.Home {
    public static func aws(region: String = "us-east-1") -> Self {
        .init(region: region)
    }
}
