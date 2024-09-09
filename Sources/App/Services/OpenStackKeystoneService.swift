
import Vapor
import Foundation

final class OpenStackKeystoneService {
    private let client: Client
    private let authURL: String
    private let appId: String
    private let appSecret: String

    // Cached token and expiration
    private(set) var authToken: String?
    private(set) var tokenExpiration: Date?

    // The Swift storage URL from the service catalog
    private(set) var swiftStorageURL: String?

    init(client: Client) throws {
        guard let authURL = Environment.get("KEYSTONE_AUTH_URL") else {
            throw Abort(.internalServerError, reason: "Missing KEYSTONE_AUTH_URL environment variable")
        }

        guard let appId = Environment.get("KEYSTONE_APP_ID") else {
            throw Abort(.internalServerError, reason: "Missing KEYSTONE_APP_ID environment variable")
        }

        guard let appSecret = Environment.get("KEYSTONE_APP_SECRET") else {
            throw Abort(.internalServerError, reason: "Missing KEYSTONE_APP_SECRET environment variable")
        }

        self.client = client
        self.authURL = authURL
        self.appId = appId
        self.appSecret = appSecret
    }

    // Struct for the authentication payload, conforming to Content
    struct KeystoneAuthPayload: Content {
        struct Auth: Content {
            struct Identity: Content {
                struct ApplicationCredential: Content {
                    let id: String
                    let secret: String
                }
                let application_credential: ApplicationCredential
                let methods: [String]
            }
            let identity: Identity
        }
        let auth: Auth
    }

    // Authenticate with Keystone and get the token
    func authenticate() async throws {
        let authPayload = KeystoneAuthPayload(
            auth: KeystoneAuthPayload.Auth(
                identity: KeystoneAuthPayload.Auth.Identity(
                    application_credential: KeystoneAuthPayload.Auth.Identity.ApplicationCredential(
                        id: appId,
                        secret: appSecret
                    ),
                    methods: ["application_credential"]
                )
            )
        )

        let response = try await client.post("\(authURL)/v3/auth/tokens", headers: ["Content-Type": "application/json"]) { req in
            try req.content.encode(authPayload)
        }

        guard response.status == .created else {
            throw Abort(.unauthorized, reason: "Failed to authenticate with Keystone")
        }

        if let token = response.headers["X-Subject-Token"].first {
            self.authToken = token
        } else {
            throw Abort(.internalServerError, reason: "No auth token returned from Keystone")
        }

        let catalog = try response.content.decode(KeystoneCatalogResponse.self)
        self.tokenExpiration = catalog.token.expires_at.toDate()
        self.swiftStorageURL = extractSwiftStorageURL(from: catalog)

        guard let _ = self.swiftStorageURL else {
            throw Abort(.internalServerError, reason: "Swift Storage URL not found in service catalog")
        }
    }

    // Check if the token is expired
    private func isTokenExpired() -> Bool {
        guard let expiration = tokenExpiration else {
            return true
        }
        return Date() >= expiration
    }

    // Get cached auth token or authenticate if expired
    func getAuthToken() async throws -> String {
        if let token = authToken, !isTokenExpired() {
            return token
        } else {
            try await authenticate()
            return authToken!
        }
    }

    private func extractSwiftStorageURL(from catalog: KeystoneCatalogResponse) -> String? {
        for service in catalog.token.catalog {
            if service.type == "object-store", let endpoint = service.endpoints.first(where: { $0.interface == "public" }) {
                return endpoint.url
            }
        }
        return nil
    }
}

extension String {
    func toDate() -> Date? {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.date(from: self)
    }
}

struct KeystoneCatalogResponse: Content {
    let token: KeystoneToken
}

struct KeystoneToken: Content {
    let expires_at: String
    let catalog: [KeystoneService]
}

struct KeystoneService: Content {
    let type: String
    let endpoints: [KeystoneEndpoint]
}

struct KeystoneEndpoint: Content {
    let interface: String
    let url: String
}
