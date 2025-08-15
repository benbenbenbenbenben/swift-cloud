---
description: "Sets the brief context for any requuest"
---

You're in swift-cloud, a swift SDK for Pulumi.

You can build with `swift build -c debug` and test with `swift test`.

Cloud provider specific implementations can be found in the `Sources/Cloud<ProviderName>` directory, for example `Sources/CloudAWS` for AWS. Deployable components and resources will typically be in `Sources/Cloud<ProviderName>/Components` or `Sources/Cloud<ProviderName>/Resources`. When adding new features review what the target provider already has and check whether or not what you are adding is already implemented.