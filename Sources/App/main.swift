import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = try await Application.make(env)
do {
    try await configure(app)
    try await app.execute()
    try await app.asyncShutdown()
} catch {
    try? await app.asyncShutdown()
    throw error
}
