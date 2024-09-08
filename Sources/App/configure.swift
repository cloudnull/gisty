import Vapor
import Leaf

public func configure(_ app: Application) async throws {
    let fileMiddleware = FileMiddleware(
        publicDirectory: app.directory.publicDirectory
    )
    app.middleware.use(fileMiddleware)

    // Register Leaf as the view renderer
    app.views.use(.leaf)

    // Initialize the OpenStack Keystone service, fetching credentials from environment variables
    let keystoneService = try OpenStackKeystoneService(client: app.client)

    // Perform Keystone authentication at startup to obtain the Swift storage URL
    try await keystoneService.authenticate()

    // Initialize the OpenStack Swift client using the dynamic Swift URL and Keystone service
    let swiftClient = try OpenStackSwiftClient(client: app.client, keystoneService: keystoneService)
    try await swiftClient.createContainer()

    // Register routes and pass the Swift client to the WebController
    let webController = WebController(swiftClient: swiftClient)
    try app.routes.register(collection: webController)
}
