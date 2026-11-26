//
//  WebElementCaptureTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies logical DOM targets, native host ownership and stale-read rejection.
//

import WebKit
import XCTest
@testable import Userpilot

final class WebElementCaptureTests: XCTestCase {
    func testDOMGeometryUsesViewportScaleAndWeakHostOwnership() throws {
        let data = Data(Self.snapshotJSON.utf8)
        let snapshot = try JSONDecoder().decode(WebElementSnapshot.self, from: data)
        var host: UIView? = UIView()
        weak let weakHost = host
        let viewport = CGRect(x: 10, y: 20, width: 200, height: 300)
        let nodes = snapshot.nodes(in: try XCTUnwrap(host), viewport: viewport, clip: viewport)
        let node = try XCTUnwrap(nodes.first)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(node.bounds, CGRect(x: 30, y: 60, width: 60, height: 80))
        XCTAssertNil(node.view)
        XCTAssertTrue(node.ownershipView === host)
        XCTAssertEqual(node.selector?.toMap(), ["userpilot_id": "checkout", "tag": "#buy"])
        XCTAssertFalse(node.isTransparent, "A reply without the marker is a visible element")
        host = nil
        XCTAssertNil(weakHost)
        XCTAssertNil(node.ownershipView)
    }

    @MainActor func testMovedWebViewDropsLateDOMReply() throws {
        let (window, webView) = makeStub()
        var results: [[ElementNode]] = []
        webView.captureUserpilotElements(clip: window.bounds) { results.append($0) }
        XCTAssertNotNil(webView.reply)
        webView.frame.origin.x += 10
        let snapshot = try JSONSerialization.jsonObject(with: Data(Self.snapshotJSON.utf8))
        webView.reply?(snapshot, nil)
        webView.reply?(snapshot, nil)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(try XCTUnwrap(results.first).isEmpty)
    }

    @MainActor func testDetachedWebViewDropsLateDOMReply() throws {
        let (window, webView) = makeStub()
        var results: [[ElementNode]] = []
        webView.captureUserpilotElements(clip: window.bounds) { results.append($0) }
        webView.removeFromSuperview()
        webView.reply?(try JSONSerialization.jsonObject(with: Data(Self.snapshotJSON.utf8)), nil)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(try XCTUnwrap(results.first).isEmpty)
    }

    func testRealDOMInventoryMarksTransparentElementsAndExcludesHiddenOnes() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        window.rootViewController = UIViewController()
        let webView = WKWebView(frame: window.bounds)
        window.rootViewController?.view.addSubview(webView)
        window.isHidden = false
        defer { window.isHidden = true }
        let completed = expectation(description: "real WebKit DOM capture")
        let delegate = WebLoadDelegate()
        webView.navigationDelegate = delegate
        delegate.loaded = {
            NativeElementTargetingStrategy().captureLayout(in: window) { tree in
                let nodes = tree.map { self.domNodes($0) } ?? []
                let identities = nodes.compactMap { $0.selector?.toMap() }
                XCTAssertEqual(identities.count, 3)
                XCTAssertTrue(identities.contains(["userpilot_id": "checkout", "tag": "#buy"]))
                XCTAssertTrue(identities.contains(["tag": "#email"]))
                // A transparent element stays, marked, like a transparent native view.
                let transparent = nodes.filter(\.isTransparent).compactMap { $0.selector?.toMap() }
                XCTAssertEqual(transparent, [["tag": "#transparent"]])
                XCTAssertTrue(nodes.allSatisfy { $0.view == nil && $0.ownershipView === webView })
                XCTAssertFalse(String(describing: identities).contains("secret"))
                completed.fulfill()
            }
        }
        webView.loadHTMLString("""
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>body{margin:0}button,input{display:block;width:100px;height:30px}</style>
        <button id="buy" data-userpilot-id="checkout">secret title</button>
        <input id="email" value="secret input">
        <button id="hidden" style="display:none">hidden</button>
        <button id="invisible" style="visibility:hidden">hidden</button>
        <div style="opacity:0"><button id="transparent">hidden</button></div>
        <button id="offscreen" style="position:absolute;top:1000px">below</button>
        """, baseURL: nil)
        wait(for: [completed], timeout: 10)
        withExtendedLifetime(delegate) {}
    }

    func testRealDOMCapture_isUnaffectedByAPageThatPatchesDOMBuiltIns() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        window.rootViewController = UIViewController()
        let webView = WKWebView(frame: window.bounds)
        window.rootViewController?.view.addSubview(webView)
        window.isHidden = false
        defer { window.isHidden = true }
        let completed = expectation(description: "real WebKit DOM capture beside page patches")
        let delegate = WebLoadDelegate()
        webView.navigationDelegate = delegate
        delegate.loaded = {
            NativeElementTargetingStrategy().captureLayout(in: window) { tree in
                let identities = (tree.map { self.domNodes($0) } ?? []).compactMap { $0.selector?.toMap() }
                XCTAssertEqual(identities, [["tag": "#buy"]])
                completed.fulfill()
            }
        }
        webView.loadHTMLString("""
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>body{margin:0}button{display:block;width:100px;height:30px}</style>
        <button id="buy">Buy</button>
        <script>
        Document.prototype.querySelectorAll = function () { return []; };
        window.getComputedStyle = function () { return {display: 'none'}; };
        </script>
        """, baseURL: nil)
        wait(for: [completed], timeout: 10)
        withExtendedLifetime(delegate) {}
    }

    func testScrollEndReplyDecodesAndAMissingOrFailedReplyCountsAsNotAtEnd() {
        XCTAssertEqual(WebScrollSnapshot.atEnd(from: ["scrolls": true, "atEnd": true]), true)
        XCTAssertEqual(WebScrollSnapshot.atEnd(from: ["scrolls": true, "atEnd": false]), false)
        XCTAssertNil(WebScrollSnapshot.atEnd(from: ["scrolls": false, "atEnd": true]))
        XCTAssertEqual(WebScrollSnapshot.atEnd(from: nil), false)
        XCTAssertEqual(WebScrollSnapshot.atEnd(from: "not an object"), false)
        XCTAssertEqual(WebScrollSnapshot.atEnd(from: ["scrolls": true]), false)
    }

    func testRealDOMScrollEndFollowsTheDocumentAndAnInPageScroller() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        window.rootViewController = UIViewController()
        let webView = WKWebView(frame: window.bounds)
        window.rootViewController?.view.addSubview(webView)
        window.isHidden = false
        defer { window.isHidden = true }
        let delegate = WebLoadDelegate()
        webView.navigationDelegate = delegate
        let head = #"<meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0}</style>"#

        XCTAssertEqual(load(head + #"<div style="height:2000px"></div>"#, in: webView, delegate: delegate), false)
        XCTAssertEqual(read(after: "window.scrollTo(0, 99999)", in: webView), true)

        let inPage = head + #"<style>html,body{height:100%;overflow:hidden}</style>"#
            + #"<div id="list" style="height:100%;overflow-y:auto"><div style="height:2000px"></div></div>"#
        XCTAssertEqual(load(inPage, in: webView, delegate: delegate), false)
        XCTAssertEqual(read(after: "document.getElementById('list').scrollTop = 99999", in: webView), true)

        let short = head + #"<button>short</button>"#
        XCTAssertEqual(load(short, in: webView, delegate: delegate), .some(nil), "Nothing scrolls on a short page")
        withExtendedLifetime(delegate) {}
    }

    func testRealDOMTextSkipsFieldsEditableHiddenAndRedactedContent() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        window.rootViewController = UIViewController()
        let webView = WKWebView(frame: window.bounds)
        window.rootViewController?.view.addSubview(webView)
        window.isHidden = false
        defer { window.isHidden = true }
        let completed = expectation(description: "real WebKit DOM text")
        let delegate = WebLoadDelegate()
        webView.navigationDelegate = delegate
        delegate.loaded = {
            NativeElementTargetingStrategy().captureLayout(in: window) { tree in
                let nodes = tree.map { self.domNodes($0) } ?? []
                var texts: [String: String?] = [:]
                for node in nodes {
                    if let tag = node.selector?.toMap()["tag"] { texts[tag] = node.displayName }
                }
                XCTAssertEqual(texts["#save"], "Save")
                XCTAssertEqual(texts["#form"], "Name")
                XCTAssertEqual(texts["#balance"], .some(nil))
                XCTAssertEqual(texts["#help"], "Help")
                XCTAssertEqual(texts["#long"]??.count, 100)
                completed.fulfill()
            }
        }
        webView.loadHTMLString("""
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>body{margin:0}button,div{display:block;width:280px;height:30px;overflow:hidden}</style>
        <button id="save">Save <span style="display:none">hidden</span></button>
        <div id="form">Name <input value="typed"><textarea>draft</textarea><span contenteditable>edited</span>
          <select><option>One</option></select></div>
        <div id="balance" data-userpilot-redact>Balance 120</div>
        <div data-userpilot-redact><button id="help" data-userpilot-redact="false">Help</button></div>
        <div id="long">\(String(repeating: "word ", count: 30))</div>
        """, baseURL: nil)
        wait(for: [completed], timeout: 10)
        withExtendedLifetime(delegate) {}
    }

    /// Loads `html` and reads the scroll-end answer once the page has finished loading.
    private func load(_ html: String, in webView: WKWebView, delegate: WebLoadDelegate) -> Bool?? {
        var answer: Bool??
        let answered = expectation(description: "scroll end after load")
        delegate.loaded = {
            webView.readUserpilotScrollEnd { answer = .some($0); answered.fulfill() }
        }
        webView.loadHTMLString(html, baseURL: nil)
        wait(for: [answered], timeout: 10)
        delegate.loaded = nil
        return answer
    }

    /// Runs `script` in the page, then reads the scroll-end answer until it reports the end.
    /// A main-frame scroll reaches the web process through the UI process, a moment after the script.
    private func read(after script: String, in webView: WKWebView) -> Bool?? {
        var answer: Bool??
        let answered = expectation(description: "scroll end after script")
        func readUntilAtEnd(attemptsLeft: Int) {
            webView.readUserpilotScrollEnd { atEnd in
                answer = .some(atEnd)
                guard atEnd != true, attemptsLeft > 0 else {
                    answered.fulfill()
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    readUntilAtEnd(attemptsLeft: attemptsLeft - 1)
                }
            }
        }
        webView.evaluateJavaScript(script) { _, _ in readUntilAtEnd(attemptsLeft: 40) }
        wait(for: [answered], timeout: 10)
        return answer
    }

    private func domNodes(_ node: ElementNode) -> [ElementNode] {
        (node.nativeType == "HTMLNode" ? [node] : []) + node.children.flatMap { domNodes($0) }
    }

    private func makeStub() -> (UIWindow, PendingWebView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        window.rootViewController = UIViewController()
        let webView = PendingWebView(frame: window.bounds)
        window.rootViewController?.view.addSubview(webView)
        return (window, webView)
    }

    private static let snapshotJSON = """
    {"width":100,"height":150,"elements":[
      {"x":10,"y":20,"width":30,"height":40,"userpilotId":"checkout","tag":"#buy"},
      {"x":500,"y":20,"width":30,"height":40,"tag":"#outside"},
      {"x":10,"y":20,"width":30,"height":40}
    ]}
    """
}

/// Holds a script's completion in `reply` instead of running the script, so a test answers it or never does.
private final class PendingWebView: WKWebView {
    var reply: (@MainActor @Sendable (Any?, Error?) -> Void)?
    override func evaluateJavaScript(
        _ javaScriptString: String,
        completionHandler: (@MainActor @Sendable (Any?, Error?) -> Void)? = nil
    ) {
        reply = completionHandler
    }

    /// The Swift content-world overload forwards here.
    @available(iOS 14.0, *)
    override func __evaluateJavaScript(
        _ javaScriptString: String,
        inFrame frame: WKFrameInfo?,
        in contentWorld: WKContentWorld,
        completionHandler: (@MainActor @Sendable (Any?, Error?) -> Void)? = nil
    ) {
        reply = completionHandler
    }
}

private final class WebLoadDelegate: NSObject, WKNavigationDelegate {
    var loaded: (() -> Void)?
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded?() }
}
