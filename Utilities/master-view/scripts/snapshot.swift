// Renders the master view's page in a WKWebView and writes a PNG of it, for
// the report's screenshots and as a check that the page's scripts run
// without an error. (Headless Chrome can't start here: its singleton socket
// can't be bound.) Build and run it with regenerate.sh's `--shots`, or:
//
//   swiftc -O -o .build/master-view/snapshot Utilities/master-view/scripts/snapshot.swift
//   .build/master-view/snapshot PAGE.html OUT.png [--width 1440] [--height 1600]
//       [--y 0] [--dark] [--js 'script to run first'] [--wait 1.5]
//       [--probe 'expression whose value to print, after the wait']
//
// It prints every JavaScript error and console.error to standard error, and
// exits 1 if there was one, or if the page didn't load. It writes only OUT.png.
import AppKit
import WebKit

struct Options {
  var page = ""
  var out = ""
  var width = 1440.0
  var height = 1600.0
  var y = 0.0
  var dark = false
  var js = ""
  var wait = 1.5
  var probe = ""
}

func parse() -> Options {
  var o = Options()
  var args = Array(CommandLine.arguments.dropFirst())
  var positional: [String] = []
  while !args.isEmpty {
    let a = args.removeFirst()
    switch a {
    case "--width": o.width = Double(args.removeFirst()) ?? o.width
    case "--height": o.height = Double(args.removeFirst()) ?? o.height
    case "--y": o.y = Double(args.removeFirst()) ?? o.y
    case "--dark": o.dark = true
    case "--js": o.js = args.removeFirst()
    case "--wait": o.wait = Double(args.removeFirst()) ?? o.wait
    case "--probe": o.probe = args.removeFirst()
    default: positional.append(a)
    }
  }
  guard positional.count == 2 else {
    FileHandle.standardError.write("usage: snapshot PAGE.html OUT.png [options]\n".data(using: .utf8)!)
    exit(2)
  }
  o.page = positional[0]
  o.out = positional[1]
  return o
}

final class Errors: NSObject, WKScriptMessageHandler {
  var messages: [String] = []
  func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
    let text = "\(message.body)"
    messages.append(text)
    FileHandle.standardError.write("page error: \(text)\n".data(using: .utf8)!)
  }
}

final class Loader: NSObject, WKNavigationDelegate {
  let done: (Bool) -> Void
  init(done: @escaping (Bool) -> Void) { self.done = done }
  func webView(_ w: WKWebView, didFinish n: WKNavigation!) { done(true) }
  func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { done(false) }
  func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { done(false) }
}

let o = parse()
// A process with no window on screen gets App Nap, which can hold its timers
// for minutes; this one is waiting on the page.
let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "snapshot")
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let errors = Errors()
let config = WKWebViewConfiguration()
let forward = """
  window.addEventListener('error', function (e) { window.webkit.messageHandlers.err.postMessage(String(e.message) + ' at ' + e.filename + ':' + e.lineno); });
  (function () { var ce = console.error; console.error = function () { window.webkit.messageHandlers.err.postMessage(Array.prototype.join.call(arguments, ' ')); ce.apply(console, arguments); }; })();
  """
config.userContentController.addUserScript(WKUserScript(source: forward, injectionTime: .atDocumentStart, forMainFrameOnly: true))
config.userContentController.add(errors, name: "err")
let view = WKWebView(frame: NSRect(x: 0, y: 0, width: o.width, height: o.height), configuration: config)
if o.dark { view.appearance = NSAppearance(named: .darkAqua) } else { view.appearance = NSAppearance(named: .aqua) }
let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
window.contentView = view

func onePixelPerPoint(_ image: NSImage) -> Data? {
  let w = Int(image.size.width), h = Int(image.size.height)
  guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
  rep.size = image.size
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])
}

func finish(_ code: Int32) -> Never {
  exit(errors.messages.isEmpty ? code : 1)
}

let url = URL(fileURLWithPath: o.page)
let loader = Loader { ok in
  guard ok else {
    FileHandle.standardError.write("snapshot: the page didn't load\n".data(using: .utf8)!)
    finish(1)
  }
  let act = o.js.isEmpty ? "1" : o.js
  view.evaluateJavaScript(act) { _, err in
    if let err = err {
      FileHandle.standardError.write("snapshot: --js failed: \(err)\n".data(using: .utf8)!)
      errors.messages.append("js")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + o.wait) {
      if !o.probe.isEmpty {
        view.evaluateJavaScript(o.probe) { value, err in
          print("probe: \(value.map { "\($0)" } ?? "nil")\(err.map { " (error: \($0))" } ?? "")")
        }
      }
      let shot = WKSnapshotConfiguration()
      shot.rect = NSRect(x: 0, y: o.y, width: o.width, height: o.height - o.y)
      view.takeSnapshot(with: shot) { image, err in
        // One image pixel per CSS pixel, not the screen's two: the PNG is a third the size.
        guard let image = image, let png = onePixelPerPoint(image) else {
          FileHandle.standardError.write("snapshot: no image: \(String(describing: err))\n".data(using: .utf8)!)
          finish(1)
        }
        do { try png.write(to: URL(fileURLWithPath: o.out)) } catch {
          FileHandle.standardError.write("snapshot: can't write \(o.out): \(error)\n".data(using: .utf8)!)
          finish(1)
        }
        print("snapshot: \(o.out)")
        finish(0)
      }
    }
  }
}
view.navigationDelegate = loader
view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
// A long package detail (swift-nio's) takes 40 s to render under a load of 120.
DispatchQueue.main.asyncAfter(deadline: .now() + 240) {
  FileHandle.standardError.write("snapshot: timed out\n".data(using: .utf8)!)
  finish(1)
}
app.run()
