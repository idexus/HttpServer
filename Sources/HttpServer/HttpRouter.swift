//
//  HttpRouter.swift
//  HttpServer
//
//  Created by Pawel Krzywdzinski on 26/10/2018.
//  Copyright © 2018 Pawel Krzywdzinski.
//

import Foundation
import NIO
import NIOHTTP1


public class HttpRouter {
    internal var routers    = [String:HttpRouter]()
    
    internal var futureResponses = [String: ResponseCallback]()
}

// ---- Router factory ----

extension HttpRouter {
    public func newSubRouter(forPathComponent pathComponent: String) -> HttpRouter {
        let router = HttpRouter()
        self.register(subRouter: router, forPathComponent: pathComponent)
        return router
    }
    
    public func register(subRouter: HttpRouter, forPathComponent pathComponent: String) {
        assert(self.routers[pathComponent] == nil, "Only one router for single path component allowed.")
        self.routers[pathComponent] = subRouter
    }
    
    public func unregisterRouter(forPath path: String) {
        self.routers[path] = nil
    }
}

extension HttpRouter {
    final class ResponseCallback {
        public let method: HTTPMethod
        public let callback: (ServerRequest, ServerResponse, Future<Void>)->()
        
        init(method: HTTPMethod, callback: @escaping (ServerRequest, ServerResponse, Future<Void>)->()) {
            self.method = method
            self.callback = callback
        }
    }
}

extension HttpRouter {
    internal func resolveRequest(pathComponents: ArraySlice<String>, request: ServerRequest, response: ServerResponse) -> Bool {
        // check if there is any subrouter
        if let firstComponent = pathComponents.first,
            let router = routers[firstComponent] {
            
            return router.resolveRequest(pathComponents: pathComponents.dropFirst(), request: request, response: response)
        }
        
        let path = "/"+pathComponents.joined(separator: "/")
        if let responseCallback = self.futureResponses[path],
            responseCallback.method == request.header.method {
            
            // start response with new succeeded future
            let begin = response.eventLoop.newSucceededFuture(result: ())
            responseCallback.callback(request, response, begin)
            return true
        }
        return false
    }
}


// HttpServer router with callbacks
extension HttpRouter {
    
    public func get(_ uri: String, _ callback: @escaping (ServerRequest, ServerResponse)->(String)) {
        send(.GET, uri, callback)
    }
    
    public func post(_ uri: String, _ callback: @escaping (ServerRequest, ServerResponse)->(String)) {
        send(.POST, uri, callback)
    }
    
    public func send(_ method: HTTPMethod, _ uri: String, _ callback: @escaping (ServerRequest, ServerResponse)->(String)) {
        futureResponses[uri] = ResponseCallback(method: method, callback: {
            req, res, begin in
            begin
                .then {
                    let stringPromise: Promise<String> = begin.eventLoop.newPromise()
                    DispatchQueue.global().async {
                        stringPromise.succeed(result: callback(req,res))
                    }
                    return stringPromise.futureResult
                }
                .then { htmlString in
                    res.flushHeader()
                        .then{res.flushBody(string: htmlString)}
                        .then(res.flushEnd)
                }
                .end()
        })
    }
    
    public func builder(_ method: HTTPMethod, _ uri: String, _ callback: @escaping (ServerRequest, ServerResponse, Future<Void>)->()) {
        futureResponses[uri] = ResponseCallback(method: method, callback: callback)
    }
}
