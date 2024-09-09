
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
    func uploadContent(_ content: String, objectName: String, deleteAfterRead: String) async throws {
        try await retryOnUnauthorized {
            try await self.performUpload(
                content: content,
                objectName: objectName,
                deleteAfterRead: deleteAfterRead
            )
        }
    }

    // Method to fetch content from OpenStack Swift with retry logic
    func fetchContent(objectName: String) async throws -> returnType {
        return try await retryOnUnauthorized {
            try await self.performFetch(objectName: objectName)
        }
    }

    // Method to fetch the Headers from OpenStack Swift with retry logic
    func fetchObjectHeaders(objectName: String) async throws -> HTTPHeaders {
        return try await retryOnUnauthorized {
            try await self.performObjectHead(objectName: objectName)
        }
    }

    // Method to fetch the Headers from OpenStack Swift with retry logic
    func fetchContainerHeaders() async throws -> HTTPHeaders {
        return try await retryOnUnauthorized {
            try await self.performContainerHead()
        }
    }

    // Method to fetch content from OpenStack Swift with retry logic
    func createContainer() async throws {
        return try await retryOnUnauthorized {
            try await self.performContainerCreate()
        }
    }

    // Perform the actual upload operation (used inside retry logic)
    private func performUpload(content: String, objectName: String, deleteAfterRead: String) async throws {
        guard let swiftStorageURL = keystoneService.swiftStorageURL else {
            throw Abort(.internalServerError, reason: "Swift Storage URL not available")
        }

        let authToken = try await keystoneService.getAuthToken()

        var headers: HTTPHeaders = [
            "X-Auth-Token": authToken,
            "Content-Type": "text/plain"
        ]

        if deleteAfterRead == "on" {
            headers.add(name: "X-Object-Meta-DeleteAfterRead", value: "on")
        }

        do {
            let _ = try await performObjectHead(objectName: objectName)
        } catch {
            let response = try await client.put("\(swiftStorageURL)/\(containerName)/\(objectName)", headers: headers, content: content)
            guard response.status == .created || response.status == .accepted else {
                throw Abort(.internalServerError, reason: "Failed to upload content to Swift, status code: \(response.status)")
            }
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

        if response.headers["X-Object-Meta-DeleteAfterRead"].first == "on" {
            let _ = try await client.delete("\(swiftStorageURL)/\(containerName)/\(objectName)", headers: headers)
        }

        return returnType(
            content: response.body?.getString(at: 0, length: response.body?.readableBytes ?? 0) ?? "No content available",
            headers: response.headers
        )
    }

    // Perform the actual fetch operation (used inside retry logic)
    private func performObjectHead(objectName: String) async throws -> HTTPHeaders {
        guard let swiftStorageURL = keystoneService.swiftStorageURL else {
            throw Abort(.internalServerError, reason: "Swift Storage URL not available")
        }

        let authToken = try await keystoneService.getAuthToken()

        let headers: HTTPHeaders = [
            "X-Auth-Token": authToken
        ]

        let response = try await client.send(.HEAD, headers: headers, to: "\(swiftStorageURL)/\(containerName)/\(objectName)")

        guard response.status == .ok || response.status == .accepted || response.status == .noContent else {
            throw Abort(.internalServerError, reason: "Failed to fetch content from Swift, status code: \(response.status)")
        }

        return response.headers
    }

    // Perform the actual container create operation (used inside retry logic)
    private func performContainerCreate() async throws {
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

    // Perform the actual fetch operation (used inside retry logic)
    private func performContainerHead() async throws -> HTTPHeaders {
        guard let swiftStorageURL = keystoneService.swiftStorageURL else {
            throw Abort(.internalServerError, reason: "Swift Storage URL not available")
        }

        let authToken = try await keystoneService.getAuthToken()

        let headers: HTTPHeaders = [
            "X-Auth-Token": authToken
        ]

        let response = try await client.send(.HEAD, headers: headers, to: "\(swiftStorageURL)/\(containerName)")

        guard response.status == .ok || response.status == .accepted || response.status == .noContent else {
            throw Abort(.internalServerError, reason: "Failed to fetch content from Swift, status code: \(response.status)")
        }

        return response.headers
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
