// File: IncomingMessage.swift - create this in Sources/MicroExpress

import NIOHTTP1
import NIO

open class IncomingMessage {
    public let header   : HTTPRequestHead
    public let body: ByteBuffer?
    public var userInfo = [ String : Any ]()
    
    init(header: HTTPRequestHead, body: ByteBuffer?) {
        self.header = header
        self.body = body
    }
}

