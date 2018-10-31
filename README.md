# HttpServer

Simple Http Server based on the Swift-NIO library.

## Simple usage

```swift
let server = HttpServer(htdocs: ".")
let router = server.mainRouter

router.get("/test") { req, res in
    return "Hello world!"
}

server.listen(onPort: 8080)
```

## Router usage

GET method example

```swift
router.get("/test") { req, res in
    return "Hello GET!"
}
```

POST method with JSON decoding

```swift
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
```

## HTTP response builder

```swift
router.builder(.GET, "/build") { req, res, begin in
    begin
        .then( res.flushHeader)
        .then{ res.flushBody(string: "Hello world!") }
        .then( res.flushEnd)
        .end()
}
```

## Adding subrouters

```swift
let router2 = router.newSubRouter(forPathComponent: "router2")

/// resolves `/router2/test` path
router2.get("/test") { req, res in
    return "Hello GET!"
}
```
