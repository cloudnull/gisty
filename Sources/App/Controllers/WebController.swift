import Vapor

final class WebController: RouteCollection {
    let swiftClient: OpenStackSwiftClient

    init(swiftClient: OpenStackSwiftClient) {
        self.swiftClient = swiftClient
    }

    func boot(routes: RoutesBuilder) throws {
        routes.get(use: renderWeb)
        routes.on(.POST, "create", body: .collect(maxSize: "100mb"), use: handleSubmit)
        let webRoute = routes.grouped(":hashedContent")
        webRoute.get(use: renderContent)
        webRoute.get("raw", use: renderContentRaw)
    }

    // Render the web view
    func renderWeb(req: Request) async throws -> View {
        return try await req.view.render("web", ["currentPath": req.url.path])
    }

    // Handle web submission, hash the content using SHA-1, and use the hash as the object name
    func handleSubmit(req: Request) async throws -> Response {
        let textInput = try req.content.get(String.self, at: "textInput")

        // Hash the content using SHA-1
        let hashedContent = Insecure.SHA1.hash(data: Data(textInput.utf8))
        let objectName = hashedContent.compactMap { String(format: "%02x", $0) }.joined() // Convert hash to a hex string

        // Upload the content to OpenStack Swift using the hash as the object name
        try await swiftClient.uploadContent(textInput, objectName: objectName)

        return req.redirect(to: "/\(objectName)")
    }

    func renderContent(req: Request) async throws -> View {
        guard let contentHash = req.parameters.get("hashedContent") else {
            return try await req.view.render("error", ["content": "No content available", "currentPath": req.url.path,])
        }
        do {
            var pasteContent: OpenStackSwiftClient.returnType!
            let clock = ContinuousClock()
            let result = try await clock.measure {
                pasteContent = try await swiftClient.fetchContent(objectName: contentHash)
            }
            let duration = Float(result.components.attoseconds) / 1000000000000000000.0
            return try await req.view.render(
                "get",
                [
                    "pasteContent": pasteContent.content,
                    "pasteHeaderLastModified": pasteContent.headers["Last-Modified"].first,
                    "pasteHeaderContentLength": pasteContent.headers["Content-Length"].first,
                    "pasteHeaderContentType": pasteContent.headers["Content-Type"].first,
                    "currentPath": req.url.path,
                    "currentHash": contentHash,
                    "returnTime": String(duration)
                ]
            )
        } catch {
            return try await req.view.render("error", ["content": "No content available", "currentPath": req.url.path,])
        }
    }

    func renderContentRaw(req: Request) async throws -> Response {
        guard let contentHash = req.parameters.get("hashedContent") else {
            return Response(status: .notFound, body: .init(string: "No content available"))
        }
        let pasteContent = try await swiftClient.fetchContent(objectName: contentHash)
        return Response(status: .ok, headers: pasteContent.headers, body: .init(string: pasteContent.content))
    }
}
