import Vapor

final class WebController: RouteCollection {
    let swiftClient: OpenStackSwiftClient

    init(swiftClient: OpenStackSwiftClient) {
        self.swiftClient = swiftClient
    }

    func boot(routes: RoutesBuilder) throws {
        routes.get(use: renderWeb)
        routes.get("about", use: renderAbout)
        routes.get("api", use: renderApi)
        routes.on(.POST, "create", body: .collect(maxSize: "100mb"), use: handleSubmit)
        let webRoute = routes.grouped(":hashedContent")
        webRoute.get(use: renderContent)
        webRoute.get("raw", use: renderContentRaw)
        webRoute.get("link", use: renderLink)
    }

    // Render the web view
    func renderWeb(req: Request) async throws -> View {
        return try await req.view.render("web", ["currentPath": req.url.path])
    }

    // Render the api view
    func renderApi(req: Request) async throws -> View {
        return try await req.view.render("api", ["currentPath": req.url.path])
    }

    // Render the api view
    func renderLink(req: Request) async throws -> View {
        guard let contentHash = req.parameters.get("hashedContent") else {
            return try await req.view.render("error", ["content": "No content available", "currentPath": req.url.path,])
        }
        return try await req.view.render("link", ["currentPath": req.url.path, "currentHash": contentHash])
    }

    // Render the about view
    func renderAbout(req: Request) async throws -> View {
        let containerHeaders = try await swiftClient.fetchContainer()
        return try await req.view.render(
            "about",
            [
                "currentObjects": containerHeaders["X-Container-Object-Count"].first,
                "currentBytes": containerHeaders["X-Container-Bytes-Used"].first,
                "lastModified": containerHeaders["Date"].first,
                "currentPath": req.url.path,
            ]
        )
    }

    // Handle web submission, hash the content using SHA-1, and use the hash as the object name
    func handleSubmit(req: Request) async throws -> Response {
        struct userInput: Content {
            let textInput: String?
            var deleteAfterRead: String?
        }
        let userContent = try req.content.decode(userInput.self)
        let deleteAfterRead = userContent.deleteAfterRead ?? "off"
        guard let inputText = userContent.textInput else {
            return Response(status: .badRequest, body: .init(string: "No content provided."))
        }

        // This ensures that two users with the same content don't run into a hash collision should one of them enable delete on read.
        var hashedContent: Insecure.SHA1Digest
        if deleteAfterRead == "off" {
            hashedContent = Insecure.SHA1.hash(data: Data(inputText.utf8))
        } else {
            let randomHash = SHA512.hash(data: Data(inputText.utf8)).compactMap { String(format: "%02x", $0) }.joined() // Convert hash to a hex string
            hashedContent = Insecure.SHA1.hash(data: Data(randomHash.utf8))
        }
        // Hash the content using SHA-1
        let objectName = hashedContent.compactMap { String(format: "%02x", $0) }.joined() // Convert hash to a hex string

        // Upload the content to OpenStack Swift using the hash as the object name
        try await swiftClient.uploadContent(inputText, objectName: objectName, deleteAfterRead: deleteAfterRead)
        if deleteAfterRead == "off" {
            return req.redirect(to: "/\(objectName)", redirectType: .permanent)
        } else {
            return req.redirect(to: "/\(objectName)/link", redirectType: .permanent)
        }
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
        var pasteContent: OpenStackSwiftClient.returnType!
        let clock = ContinuousClock()
        let result = try await clock.measure {
            pasteContent = try await swiftClient.fetchContent(objectName: contentHash)
        }
        let duration = Float(result.components.attoseconds) / 1000000000000000000.0
        var headers = pasteContent.headers
        headers.add(name: "X-Round-Trip-Time", value: String(duration))
        return Response(status: .ok, headers: headers, body: .init(string: pasteContent.content))
    }
}
