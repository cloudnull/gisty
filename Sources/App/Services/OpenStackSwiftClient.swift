
import Vapor

final class OpenStackSwiftClient {
    private let client: Client
    private let keystoneService: OpenStackKeystoneService
    private let containerName: String

    struct returnType: Content {
        let content: String
        let headers: HTTPHeaders
    }

    init(client: Client, keystoneService: OpenStackKeystoneService) throws {
        self.client = client
        self.keystoneService = keystoneService

        guard let containerName = Environment.get("SWIFT_CONTAINER_NAME") else {
            throw Abort(.internalServerError, reason: "Missing SWIFT_CONTAINER_NAME environment variable")
        }

        self.containerName = containerName
    }

    // Method to upload content to OpenStack Swift with retry logic
    func uploadContent(_ content: String, objectName: String) async throws {
        try await retryOnUnauthorized {
            try await self.performUpload(content: content, objectName: objectName)
        }
    }

    // Method to fetch content from OpenStack Swift with retry logic
    func fetchContent(objectName: String) async throws -> returnType {
        return try await retryOnUnauthorized {
            try await self.performFetch(objectName: objectName)
        }
    }

    // Method to fetch content from OpenStack Swift with retry logic
    func createContainer() async throws {
        return try await retryOnUnauthorized {
            try await self.performCreate()
        }
    }

    // Perform the actual create operation (used inside retry logic)
    private func performCreate() async throws {
        guard let swiftStorageURL = keystoneService.swiftStorageURL else {
            throw Abort(.internalServerError, reason: "Swift Storage URL not available")
        }

        let authToken = try await keystoneService.getAuthToken()

        let headers: HTTPHeaders = [
            "X-Auth-Token": authToken,
            "Content-Type": "text/plain"
        ]

        let response = try await client.put("\(swiftStorageURL)/\(containerName)", headers: headers)

        guard response.status == .created || response.status == .accepted else {
            throw Abort(.internalServerError, reason: "Failed to create Swift container, status code: \(response.status)")
        }
    }

    // Perform the actual upload operation (used inside retry logic)
    private func performUpload(content: String, objectName: String) async throws {
        guard let swiftStorageURL = keystoneService.swiftStorageURL else {
            throw Abort(.internalServerError, reason: "Swift Storage URL not available")
        }

        let authToken = try await keystoneService.getAuthToken()

        let headers: HTTPHeaders = [
            "X-Auth-Token": authToken,
            "Content-Type": "text/plain"
        ]

        let response = try await client.put("\(swiftStorageURL)/\(containerName)/\(objectName)", headers: headers, content: content)

        guard response.status == .created || response.status == .accepted else {
            throw Abort(.internalServerError, reason: "Failed to upload content to Swift, status code: \(response.status)")
        }
    }

    // Perform the actual fetch operation (used inside retry logic)
    private func performFetch(objectName: String) async throws -> returnType {
        guard let swiftStorageURL = keystoneService.swiftStorageURL else {
            throw Abort(.internalServerError, reason: "Swift Storage URL not available")
        }

        let authToken = try await keystoneService.getAuthToken()

        let headers: HTTPHeaders = [
            "X-Auth-Token": authToken
        ]

        let response = try await client.get("\(swiftStorageURL)/\(containerName)/\(objectName)", headers: headers)

        guard response.status == .ok else {
            throw Abort(.internalServerError, reason: "Failed to fetch content from Swift, status code: \(response.status)")
        }

        return returnType(
            content: response.body?.getString(at: 0, length: response.body?.readableBytes ?? 0) ?? "No content available",
            headers: response.headers
        )
    }

    // Generic method to retry on 401 Unauthorized
    private func retryOnUnauthorized<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var attempts = 0
        let maxAttempts = 3

        while attempts < maxAttempts {
            do {
                return try await operation()
            } catch {
                if let abortError = error as? AbortError, abortError.status == .unauthorized {
                    attempts += 1
                    if attempts < maxAttempts {
                        try await keystoneService.authenticate()
                    } else {
                        throw Abort(.unauthorized, reason: "Unauthorized after \(maxAttempts) attempts.")
                    }
                } else {
                    throw error
                }
            }
        }
        throw Abort(.internalServerError, reason: "Failed to perform operation after \(maxAttempts) attempts.")
    }
}
