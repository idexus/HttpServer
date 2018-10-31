//
//  ServerRequest.swift
//  HttpServer
//
//  Created by Pawel Krzywdzinski on 08/10/2018.
//  Copyright © 2018 Pawel Krzywdzinski.
//

import Foundation
import NIO
import NIOHTTP1

public class ServerRequest {
    
    internal let context        : ChannelHandlerContext

    public let header           : HTTPRequestHead
    public let queryItems       : [String:String]
    public var data             : Data!

    init(header: HTTPRequestHead, context: ChannelHandlerContext) {
        
        self.header = header
        self.context = context
        
        if let allQueryItems = URLComponents(string: header.uri)?.queryItems {
            self.queryItems = Dictionary(grouping: allQueryItems, by: { $0.name })
                .mapValues { $0.compactMap({ $0.value?.removingPercentEncoding })
                    .joined(separator: ",") }
        } else {
            self.queryItems = [String:String]()
        }
    }
}

// ---- reading request data ----

extension ServerRequest {
    
    /// Reads body data from ByteBuffer.
    func readBodyDataFrom(buffer: ByteBuffer) {
        if self.data == nil {
            self.data = Data(bytes: buffer.readableBytesView)
        } else {
            self.data.append(contentsOf: buffer.readableBytesView)
        }
    }
}
