import Vapor

var env: Environment = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app: Application = Application(env)
defer {
    app.shutdown()
}
try await configure(app)
try await app.execute()
