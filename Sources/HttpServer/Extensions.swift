//
//  Extensions.swift
//  HttpServer
//
//  Created by Pawel Krzywdzinski on 11/10/2018.
//  Copyright © 2018 Pawel Krzywdzinski.
//

import Foundation
import NIO


public typealias Future = EventLoopFuture
public typealias Promise = EventLoopPromise

public func unwrapJson<T : Codable>(_ data: Data?) -> T? {
    guard let data = data else {
        return nil
    }
    return try? JSONDecoder().decode(T.self, from: data)
}

extension Array where Element == UInt8 {
    var data : Data{
        return Data(bytes:(self))
    }
}


extension EventLoopFuture {
    public func end() {
        self.whenFailure { error in
            print("Event Loop error:", error)
        }
    }
}
