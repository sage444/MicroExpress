// File: ServerResponse.swift - create this in Sources/MicroExpress

import NIO
import NIOHTTP1

open class ServerResponse {
  
  public  var status         = HTTPResponseStatus.ok
  public  var headers        = HTTPHeaders()
  public  let channel        : Channel
  private var didWriteHeader = false
  private var didEnd         = false
  
  public init(channel: Channel) {
    self.channel = channel
  }

  /// An Express like `send()` function.
  open func send(_ s: String) {
    flushHeader()
    guard !didEnd else { return }
    
    let utf8   = s.utf8
    var buffer = channel.allocator.buffer(capacity: utf8.count)
    #if swift(>=5) // NIO2
      buffer.writeBytes(utf8)
    #else
      buffer.write(bytes: utf8)
    #endif
    
    let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
    
    #if swift(>=5)
      _ = channel.writeAndFlush(part)
                 .recover(handleError)
                 .map { self.end() }
    #else
      _ = channel.writeAndFlush(part)
                 .mapIfError(handleError)
                 .map { self.end() }
    #endif
  }
  
  /// Check whether we already wrote the response header.
  /// If not, do so.
  func flushHeader() {
    guard !didWriteHeader else { return } // done already
    didWriteHeader = true
    
    let head = HTTPResponseHead(version: .init(major:1, minor:1),
                                status: status, headers: headers)
    let part = HTTPServerResponsePart.head(head)
    #if swift(>=5)
      _ = channel.writeAndFlush(part).recover(handleError)
    #else
      _ = channel.writeAndFlush(part).mapIfError(handleError)
    #endif
  }
  
  func handleError(_ error: Error) {
    print("ERROR:", error)
    end()
  }
  
  func end() {
    guard !didEnd else { return }
    didEnd = true
    _ = channel.writeAndFlush(HTTPServerResponsePart.end(nil))
               .map { self.channel.close() }
  }
}

public extension ServerResponse {
  
  /// A more convenient header accessor. Not correct for
  /// any header.
  subscript(name: String) -> String? {
    set {
      assert(!didWriteHeader, "header is out!")
      if let v = newValue {
        headers.replaceOrAdd(name: name, value: v)
      }
      else {
        headers.remove(name: name)
      }
    }
    get {
      return headers[name].joined(separator: ", ")
    }
  }
}

#if swift(>=5)

public extension ServerResponse {

  /// An Express like `send()` function which arbitrary "Data" objects
  /// (i.e. collections of type UInt8)
  func send<S: Collection>(bytes: S) where S.Element == UInt8 {
    flushHeader()
    guard !didEnd else { return }

    var buffer = channel.allocator.buffer(capacity: bytes.count)
    #if swift(>=5) // NIO2
      buffer.writeBytes(bytes)
    #else
      buffer.write(bytes: bytes)
    #endif
    
    let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
    
    #if swift(>=5)
      _ = channel.writeAndFlush(part)
                 .recover(handleError)
                 .map { self.end() }
    #else
      _ = channel.writeAndFlush(part)
                 .mapIfError(handleError)
                 .map { self.end() }
    #endif
  }

}

#elseif swift(>=4.1) // Needs a different imp for 4.0

public extension ServerResponse {

  /// An Express like `send()` function which arbitrary "Data" objects
  /// (i.e. collections of type UInt8)
  func send<S: ContiguousCollection>(bytes: S) where S.Element == UInt8 {
    flushHeader()
    guard !didEnd else { return }

    var buffer = channel.allocator.buffer(capacity: bytes.count)
    buffer.write(bytes: bytes)
    
    let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
    
    _ = channel.writeAndFlush(part)
               .mapIfError(handleError)
               .map { self.end() }
  }

}

#endif


import Foundation


// MARK: - JSON

public extension ServerResponse {
  
  /// Send a Codable object as JSON to the client.
  func json<T: Encodable>(_ model: T) {
    // create a Data struct from the Codable object
    let data : Data
    do {
      data = try JSONEncoder().encode(model)
    }
    catch {
      return handleError(error)
    }
    
    // setup JSON headers
    self["Content-Type"]   = "application/json"
    self["Content-Length"] = "\(data.count)"
    
    // send the headers and the data
    flushHeader()
    guard !didEnd else { return }

    var buffer = channel.allocator.buffer(capacity: data.count)
    #if swift(>=5) // NIO2
      buffer.writeBytes(data)
    #else
      buffer.write(bytes: data)
    #endif
    let part = HTTPServerResponsePart.body(.byteBuffer(buffer))

    #if swift(>=5)
      _ = channel.writeAndFlush(part)
                 .recover(handleError)
                 .map { self.end() }
    #else
      _ = channel.writeAndFlush(part)
                 .mapIfError(handleError)
                 .map { self.end() }
    #endif
  }
}


// MARK: - Mustache

import mustache

public extension ServerResponse {
  
  func render(pathContext : String = #file,
              _ template: String, _ options : Any? = nil)
  {
    let res = self
    
    // Locate the template file
    let path = self.path(to: template, ofType: "mustache",
                         in: pathContext)
            ?? "/dummyDoesNotExist"
    
    // Read the template file
    fs.readFile(path) { err, data in
      guard var data = data else {
        res.status = .internalServerError
        return res.send("Error: \(err as Optional)")
      }
      
      #if swift(>=5) // NIO2
        data.writeBytes([0]) // cstr terminator
      #else
        data.write(bytes: [0]) // cstr terminator
      #endif
      
      // Parse the template
      let parser = MustacheParser()
      let tree   : MustacheNode = data.withUnsafeReadableBytes {
        let ba  = $0.baseAddress!
        let bat = ba.assumingMemoryBound(to: CChar.self)
        return parser.parse(cstr: bat)
      }
      
      // Render the response
      let result = tree.render(object: options)
      
      // Deliver
      res["Content-Type"] = "text/html"
      res.send(result)
    }
  }
  
  private func path(to resource: String, ofType: String,
                    in pathContext: String) -> String?
  {
    #if os(iOS) && !arch(x86_64) // iOS support, FIXME: blocking ...
      return Bundle.main.path(forResource: resource, ofType: "mustache")
    #else
      var url = URL(fileURLWithPath: pathContext)
      url.deleteLastPathComponent()
      url.appendPathComponent("templates", isDirectory: true)
      url.appendPathComponent(resource)
      url.appendPathExtension("mustache")
      return url.path
    #endif
  }
}
