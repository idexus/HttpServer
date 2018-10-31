//
//  ServerResponse.swift
//  HttpServer
//
//  Created by Pawel Krzywdzinski on 08/10/2018.
//  Copyright © 2018 Pawel Krzywdzinski.
//

import Foundation
import NIO
import NIOHTTP1

public class ServerResponse {
    
    public  var status          = HTTPResponseStatus.ok
    
    private let httpServer      : HttpServer
    private let request         : ServerRequest
    
    private var headerFlushed   = false
    
    // helpful shortcuts
    internal var channel        : Channel { return self.request.context.channel }
    internal var eventLoop      : EventLoop { return self.request.context.channel.eventLoop }
    internal var allocator      : ByteBufferAllocator { return self.request.context.channel.allocator }
    internal var fileIO         : NonBlockingFileIO { return self.httpServer.fileIO }
    
    private var headers         = HTTPHeaders()
    
    public init(serverRequest : ServerRequest, httpServer : HttpServer) {
        self.request = serverRequest
        self.httpServer = httpServer
    }
}


// ----- Send response -----

extension ServerResponse {
    /// Sends response via router or sends file
    internal func sendResponse() {
        // first try routers
        if let urlComponents = URLComponents(string: self.request.header.uri),
            let pathComponents = urlComponents.url?.pathComponents.dropFirst() {
            if self.httpServer.mainRouter.resolveRequest(pathComponents: pathComponents, request: request, response: self) {
                return
            }
        }
        // then try to send file
        if request.header.method == .GET {
            sendFile(path: request.header.uri)
        } else {
            status = .badRequest
            sendResponseWithError(ServerError.badRequest).end()
        }
    }
}

// ----- Private - send functions -----

extension ServerResponse {
    /// Sends content of file
    private func sendFile(path : String) {
        let path = self.httpServer.htdocs + path
        print("GET:", path)
        
        self.openFile(path: path)
            .then {
                fileRegion -> Future<Void> in
                self.flushHeader()
                    .then { self.flushFromFile(fileRegion: fileRegion) }
                    .then( self.flushEnd )
                    .map { try? fileRegion.fileHandle.close() }
                    .thenIfErrorThrowing { error in
                        try? fileRegion.fileHandle.close()
                        throw ServerError.fileResponseError
                    }
            }
            .thenIfError { _ in self.sendResponseWithError(ServerError.fileNotFound(path)) }
            .end()
    }
    
    /// Sends response with error.
    private func sendResponseWithError(_ error: Error) -> Future<Void> {
        return flushHeader()
            .then{ self.flushErrorBody(error) }
            .then( flushEnd )
    }
}

// ----- File Flush fuctions -----

extension ServerResponse {
    
    /// Opens file and give back `FileRegion`.
    public func openFile(path: String) -> Future<FileRegion> {
        return
            self.fileIO.openFile(path: path, eventLoop: self.eventLoop)
                .map { $0.1 }
    }
    
    /// Flushes async BODY from File.
    public func flushFromFile(fileRegion: FileRegion) -> Future<Void> {
        
        let fileChunkSize   = 1024
        
        return self.fileIO.readChunked(fileRegion : fileRegion,
                                       chunkSize  : fileChunkSize,
                                       allocator  : self.allocator,
                                       eventLoop  : self.eventLoop)
        {
            buffer in
            
            let bodyPart = HTTPServerResponsePart.body(.byteBuffer(buffer))
            return self.channel.writeAndFlush(bodyPart)
        }
            .thenIfErrorThrowing { _ in throw ServerError.fileResponseError }
    }
}

// ----- Public async operations - Flush fuctions -----

extension ServerResponse {
    
    /// Flushes async HEADER.
    public func flushHeader() -> Future<Void> {
        
        if headerFlushed {
            return self.eventLoop.newSucceededFuture(result: ())
        }
        
        let head = HTTPResponseHead(version: .init(major:1, minor:1),
                                    status: status, headers: headers)
        let headPart = HTTPServerResponsePart.head(head)
        
        return self.channel.writeAndFlush(headPart)
            .map { self.headerFlushed = true }
    }
    
    /// Flushes async BODY.
    public func flushBody(string: String) -> Future<Void> {
        let utf8   = string.utf8
        var buffer = self.allocator.buffer(capacity: utf8.count)
        buffer.write(bytes: utf8)
        
        let bodyPart = HTTPServerResponsePart.body(.byteBuffer(buffer))
        
        return self.channel.writeAndFlush(bodyPart)
    }
    
    /// Flushes async BODY with error.
    public func flushErrorBody(_ error: Error) -> Future<Void> {
        
        let serverError = error as? ServerError
        
        return self.flushBody(string: serverError?.description() ?? error.localizedDescription)
    }
    
    /// Flushes async END.
    public func flushEnd() -> Future<Void> {
        
        let endPart = HTTPServerResponsePart.end(nil)
        
        return self.channel.writeAndFlush(endPart)
    }
}

// ----- errors -----

extension ServerResponse {
    enum ServerError: Error {
        case fileNotFound(String)
        case fileResponseError
        case badRequest
        
        func description() -> String {
            switch self {
            case .fileNotFound(let name): return "File not found: \(name)"
            case .fileResponseError: return "File response error"
            case .badRequest: return "Bad request"
            }
        }
    }
    
    /// Log error
    private func handleError( _ error : Error) {
        print("Error : \(error.localizedDescription)")
    }
}
