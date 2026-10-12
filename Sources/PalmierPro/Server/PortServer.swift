#if !os(macOS)
import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1

/// Local HTTP server exposing the portable core to cross-platform UI.
/// macOS uses the native app; Linux/Windows serve this API plus the bundled web UI.
enum PortServer {
    static let preferredPort = 19790

    /// Binds the first free port starting at `preferredPort`, opens the UI in
    /// the default browser unless disabled, then serves until killed.
    static func start(preferredPort: Int = PortServer.preferredPort, openBrowser: Bool = true) throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try? group.syncShutdownGracefully() }
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(PortHTTPHandler())
                }
            }

        var bound: (channel: Channel, port: Int)?
        var lastError: Error?
        for port in preferredPort..<(preferredPort + 16) {
            do {
                bound = (try bootstrap.bind(host: "127.0.0.1", port: port).wait(), port)
                break
            } catch {
                lastError = error
            }
        }
        guard let bound else {
            throw lastError ?? PortServerError.noFreePort
        }
        let (channel, port) = bound

        let url = "http://127.0.0.1:\(port)/"
        Log.app.notice("port server listening url=\(url)")
        print("""
        Palmier Pro timeline UI: \(url)
        Keep this window open; press Ctrl-C to stop.

        """)
        if openBrowser {
            openInBrowser(url)
        }
        try channel.closeFuture.wait()
    }

    private static func openInBrowser(_ url: String) {
        #if os(Windows)
        let exe = "C:\\Windows\\System32\\cmd.exe"
        let args = ["/c", "start", "", url]
        #else
        let exe = "/usr/bin/xdg-open"
        let args = [url]
        #endif
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exe)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            Log.app.info("browser open failed: \(Log.detail(error))")
        }
    }
}

enum PortServerError: Error {
    case noFreePort
}

private struct ProjectPayload: Encodable {
    let name: String
    let fps: Int
    let timeline: Timeline?
}

final class PortHTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private var head: HTTPRequestHead?

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let h):
            head = h
        case .body:
            break
        case .end:
            guard let head else { return }
            self.head = nil
            route(context: context, head: head)
        }
    }

    private func route(context: ChannelHandlerContext, head: HTTPRequestHead) {
        let path = String(head.uri.split(separator: "?")[0])
        switch (head.method, path) {
        case (.GET, "/api/health"):
            send(context: context, head: head, status: .ok,
                 contentType: "application/json", body: Data(#"{"ok":true}"#.utf8))
        case (.GET, "/api/project"):
            let payload = ProjectPayload(
                name: "Demo Project",
                fps: DemoLibrary.timeline?.fps ?? 30,
                timeline: DemoLibrary.timeline
            )
            guard let body = try? JSONEncoder().encode(payload) else {
                send(context: context, head: head, status: .internalServerError,
                     contentType: "text/plain", body: Data("encode failed".utf8))
                return
            }
            send(context: context, head: head, status: .ok,
                 contentType: "application/json", body: body)
        case (.GET, "/"), (.GET, "/index.html"):
            let body: Data
            if let url = BundledResource.url("Web/timeline.html"),
               let data = try? Data(contentsOf: url) {
                body = data
            } else {
                // Single-file fallback: binary moved without its resource dir.
                body = Data(EmbeddedWebUI.html.utf8)
            }
            send(context: context, head: head, status: .ok,
                 contentType: "text/html; charset=utf-8", body: body)
        default:
            send(context: context, head: head, status: .notFound,
                 contentType: "text/plain", body: Data("not found".utf8))
        }
    }

    private func send(
        context: ChannelHandlerContext, head: HTTPRequestHead,
        status: HTTPResponseStatus, contentType: String, body: Data
    ) {
        var headers = HTTPHeaders()
        headers.add(name: "content-type", value: contentType)
        headers.add(name: "content-length", value: "\(body.count)")
        headers.add(name: "connection", value: "close")
        context.write(wrapOutboundOut(.head(HTTPResponseHead(version: head.version, status: status, headers: headers))), promise: nil)
        var buffer = context.channel.allocator.buffer(capacity: body.count)
        buffer.writeBytes(body)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
            context.close(promise: nil)
        }
    }
}

extension PortHTTPHandler: @unchecked Sendable {}
#endif
