// File: Express.swift - create this in Sources/MicroExpress

import Foundation
import NIO
import NIOHTTP1

let loopGroup =
  MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

open class Express : Router {
  
  override public init() {}

  private func createServerBootstrap(_ backlog : Int) -> ServerBootstrap {
    let reuseAddrOpt = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET),
                                             SO_REUSEADDR)
    let bootstrap = ServerBootstrap(group: loopGroup)
      .serverChannelOption(ChannelOptions.backlog, value: Int32(backlog))
      .serverChannelOption(reuseAddrOpt, value: 1)
      
      .childChannelInitializer { channel in
        #if swift(>=5) // NIO2
          return channel.pipeline.configureHTTPServerPipeline().flatMap {
            _ in
            channel.pipeline.addHandler(HTTPHandler(router: self))
          }
        #else
          return channel.pipeline.configureHTTPServerPipeline().then {
            channel.pipeline.add(handler: HTTPHandler(router: self))
          }
        #endif
      }
      
      .childChannelOption(ChannelOptions.socket(
        IPPROTO_TCP, TCP_NODELAY), value: 1)
      .childChannelOption(reuseAddrOpt, value: 1)
      .childChannelOption(ChannelOptions.maxMessagesPerRead,
                          value: 1)
    return bootstrap
  }

  open func listen(unixSocket : String = "express.socket",
                   backlog    : Int    = 256)
  {
    let bootstrap = self.createServerBootstrap(backlog)

    do {
      let serverChannel =
        try bootstrap.bind(unixDomainSocketPath: unixSocket)
          .wait()
      print("Server running on:", socket)
      
      try serverChannel.closeFuture.wait() // runs forever
    }
    catch {
      fatalError("failed to start server: \(error)")
    }
  }
  
  open func listen(_ port    : Int    = 1337,
                   _ host    : String = "localhost",
                   _ backlog : Int    = 256)
  {
    let bootstrap = self.createServerBootstrap(backlog)
    
    do {
      let serverChannel =
        try bootstrap.bind(host: host, port: port)
          .wait()
      print("Server running on:", serverChannel.localAddress!)
      
      try serverChannel.closeFuture.wait() // runs forever
    }
    catch {
      fatalError("failed to start server: \(error)")
    }
  }

  final class HTTPHandler : ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    
    let router : Router
    var headers: HTTPRequestHead?
    var body: ByteBuffer?
    
    init(router: Router) {
      self.router = router
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let header):
            headers = header
            print("request headers receiced: \(header)")
        case .body(let body):
            if var existingData = self.body {
                var incoming = body
                let bytesWrote = existingData.writeBuffer(&incoming)
                assert(body.readableBytes == bytesWrote)
                self.body = existingData
            } else {
                self.body = body
            }
           
            print("request body receiced of size: \(body.capacity)")
        case .end:
            let headers = self.headers ?? HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "")
            let req = IncomingMessage(header: headers, body: body)
            let res = ServerResponse(channel: context.channel)
            
            // trigger Router
            router.handle(request: req, response: res) {
                (items : Any...) in // the final handler
                res.status = .notFound
                res.send("No middleware handled the request!")
            }
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
      print("socket error, closing connection:", error)
      context.close(promise: nil)
    }
    
    #if swift(>=5)
    #else // NIO 1 API shim
      func channelRead(ctx context: ChannelHandlerContext, data: NIOAny) {
        return channelRead(context: context, data: data)
      }
      func errorCaught(ctx context: ChannelHandlerContext, error: Error) {
        errorCaught(context: context, error: error)
      }
    #endif // NIO 1 API
  }
}

