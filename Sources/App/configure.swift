import Vapor
import Leaf

public func configure(_ app: Application) async throws {
    let fileMiddleware = FileMiddleware(
        publicDirectory: app.directory.publicDirectory
    )
    app.middleware.use(fileMiddleware)

    // Register Leaf as the view renderer
    app.views.use(.leaf)
    app.logger.info("Application initializing")
    // Initialize the OpenStack Keystone service, fetching credentials from environment variables
    let keystoneService = try OpenStackKeystoneService(client: app.client)

    // Perform Keystone authentication at startup to obtain the Swift storage URL
    try await keystoneService.authenticate()
    app.logger.info("Application authentication accepted")
    // Initialize the OpenStack Swift client using the dynamic Swift URL and Keystone service
    let swiftClient = try OpenStackSwiftClient(client: app.client, keystoneService: keystoneService)
    app.logger.info("Application swift container initializing")
    try await swiftClient.createContainer()
    app.logger.info("Application swift container accepted")

    // Register routes and pass the Swift client to the WebController
    app.logger.info("Application Web Controller initializing")
    try app.routes.register(collection: WebController(swiftClient: swiftClient))
}
