//
//  HttpServer.swift
//  HttpServer
//
//  Created by Pawel Krzywdzinski on 08/10/2018.
//  Copyright © 2018 Pawel Krzywdzinski.
//

import Foundation
import NIO
import NIOHTTP1

final public class HttpServer {

    private var threadPool  : BlockingIOThreadPool!
    private var loopGroup   : MultiThreadedEventLoopGroup!
    
    internal var fileIO     : NonBlockingFileIO!
    
    internal var htdocs     : String
    
    public var  mainRouter  = HttpRouter()
    
    public init(htdocs: String = "/dev/null") {
        self.htdocs = htdocs
    }
}

// ---- Main `listen` functionality ----

extension HttpServer {
    public func listen(onPort port: Int = 8080) {

        // for router non blocking IO
        self.threadPool = BlockingIOThreadPool(numberOfThreads: 6)
        self.threadPool.start()
        
        self.fileIO = NonBlockingFileIO(threadPool: threadPool)
        
        self.loopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let bootstrap = ServerBootstrap(group: loopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().then {
                    channel.pipeline.add(handler: HTTPHandler(httpServer: self))
                }
            }
            
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        
        defer {
            try! loopGroup.syncShutdownGracefully()
            try! threadPool.syncShutdownGracefully()
        }
        
        do {
            let serverChannel = try bootstrap.bind(host: "localhost", port: port).wait()
            print("Server running on: \(serverChannel.localAddress!) htdocs: \(htdocs)")
            
            try serverChannel.closeFuture.wait()
        }
        catch {
            fatalError("failed to start server: \(error)")
        }
    }
}

// ---- Channel inbound handler ----

extension HttpServer {
    final class HTTPHandler : ChannelInboundHandler {
        typealias InboundIn = HTTPServerRequestPart
        
        private unowned let httpServer : HttpServer
        
        var serverRequest: ServerRequest!
        var serverResponse: ServerResponse!
        
        init(httpServer : HttpServer) {
            self.httpServer = httpServer
        }
        
        func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
            let reqPart = unwrapInboundIn(data)
            
            switch reqPart {
            case .head(let header):
                serverRequest  = ServerRequest(header: header, context: ctx)
                serverResponse = ServerResponse(serverRequest: serverRequest, httpServer: self.httpServer)
            case .body(let buffer):
                serverRequest.readBodyDataFrom(buffer: buffer)
            case .end(_):
                serverResponse.sendResponse()
            }
        }
    }
}

