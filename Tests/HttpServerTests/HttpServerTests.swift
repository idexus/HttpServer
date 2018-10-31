import XCTest
@testable import HttpServer

final class HttpServerTests: XCTestCase {
    
    var counter = 1
    
    func testExample() {
        let server = HttpServer(htdocs: "/Users/pawel/Web")
        let router1 = server.mainRouter
        let router2 = router1.newSubRouter(forPathComponent: "router2")
        
        class DataTest: Codable {
            var value1: Int
            var value2: Int
        }
        
        router1.post("/api") { req, res in
            if let dataTest: DataTest = unwrapJson(req.data) {
                return "Test: \(dataTest.value1), \(dataTest.value2)"
            }
            res.status = .badRequest
            return "Bad request!"
        }
        
        router2.get("/test") { req, res in
            return "Hello router2!"
        }
        
        router1.builder(.GET, "/build") { req, res, begin in
            begin
                .then( res.flushHeader)
                .then{ res.flushBody(string: "Hello world!") }
                .then( res.flushEnd)
                .end()
        }
        
        server.listen(onPort: 8081)
    }
    
    func testHelloWorld() {
        let server = HttpServer(htdocs: ".")
        let router = server.mainRouter
        
        router.get("/") { req, res in
            return "Hello world!"
        }
        
        server.listen(onPort: 8080)
    }

    static var allTests = [
        ("testExample", testExample),
        ("testHelloWorld", testHelloWorld),
    ]
}
