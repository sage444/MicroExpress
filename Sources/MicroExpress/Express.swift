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
    
    init(router: Router) {
      self.router = router
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      let reqPart = self.unwrapInboundIn(data)
      
      switch reqPart {
        case .head(let header):
          let req = IncomingMessage(header: header)
          let res = ServerResponse(channel: context.channel)
          
          // trigger Router
          router.handle(request: req, response: res) {
            (items : Any...) in // the final handler
            res.status = .notFound
            res.send("No middleware handled the request!")
          }

        // ignore incoming content to keep it micro :-)
        case .body, .end: break
      }
    }
    
    #if swift(>=5) // NIO 2 API
      public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("socket error, closing connection:", error)
        context.close(promise: nil)
      }
    #else // NIO 1 API
      func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        return channelRead(context: context, data: data)
      }
      public func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        print("socket error, closing connection:", error)
        ctx.close(promise: nil)
      }
    #endif // NIO 1 API
  }
}

