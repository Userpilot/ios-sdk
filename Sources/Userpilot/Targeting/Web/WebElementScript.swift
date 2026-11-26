//
//  WebElementScript.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Reads visible DOM identities, geometry and displayed text, never form values or editable content.
//  `scrollEnd` reads only whether the page's main vertical scroller is at its end.
//

import Foundation

internal enum WebElementScript {
    /// Visible elements for targeting and Builder capture.
    static let capture = script + "()"

    /// Whether the page's main vertical scroller is at its end. The main scroller is the
    /// scrolling document, or else the in-page scroller with the largest visible area, open
    /// shadow roots included (for example Ionic `ion-content`). Replies `scrolls: false` when
    /// nothing on the page scrolls vertically.
    static let scrollEnd = #"""
    (function () {
        const viewWidth = window.innerWidth, viewHeight = window.innerHeight;
        const blocks = function (element) {
            return !!element && /hidden|clip/.test(getComputedStyle(element).overflowY);
        };
        const atEnd = function (element) {
            return element.scrollTop + element.clientHeight >= element.scrollHeight - 1;
        };
        const page = document.scrollingElement || document.documentElement;
        if (page && page.scrollHeight - page.clientHeight > 1 && !blocks(page) && !blocks(document.body)) {
            return {scrolls: true, atEnd: atEnd(page)};
        }
        let main = null, mainArea = 0;
        const visit = function (root) {
            root.querySelectorAll('*').forEach(function (element) {
                if (element.shadowRoot) visit(element.shadowRoot);
                if (element.scrollHeight - element.clientHeight <= 1) return;
                if (!/auto|scroll|overlay/.test(getComputedStyle(element).overflowY)) return;
                const rect = element.getBoundingClientRect();
                const width = Math.min(rect.right, viewWidth) - Math.max(rect.left, 0);
                const height = Math.min(rect.bottom, viewHeight) - Math.max(rect.top, 0);
                if (width > 0 && height > 0 && width * height > mainArea) {
                    main = element;
                    mainArea = width * height;
                }
            });
        };
        visit(document);
        return main ? {scrolls: true, atEnd: atEnd(main)} : {scrolls: false, atEnd: true};
    })()
    """#

    private static let script = #"""
    (function () {
        const viewport = window.visualViewport;
        const width = viewport ? viewport.width : window.innerWidth;
        const height = viewport ? viewport.height : window.innerHeight;
        const offsetX = viewport ? viewport.offsetLeft : 0;
        const offsetY = viewport ? viewport.offsetTop : 0;
        const skippedTags = {TEXTAREA: true, SELECT: true, OPTION: true, SCRIPT: true, STYLE: true,
            NOSCRIPT: true, TEMPLATE: true};
        // Hidden by the app: not part of the visible screen, like a hidden native view.
        const hidden = function (style) {
            return style.display === 'none' || style.visibility === 'hidden' ||
                style.visibility === 'collapse';
        };
        // Hidden, or drawn fully transparent: neither contributes text.
        const unseen = function (style) {
            return hidden(style) || Number(style.opacity) === 0;
        };
        // Form fields, editable content and hidden nodes never contribute text, nor does a subtree
        // whose nearest data-userpilot-redact attribute is not "false".
        const hidesText = function (start, root) {
            if (start.isContentEditable) return true;
            let redacted = null;
            let insideRoot = true;
            for (let node = start; node && (insideRoot || redacted === null); node = node.parentElement) {
                if (redacted === null && node.hasAttribute('data-userpilot-redact')) {
                    redacted = node.getAttribute('data-userpilot-redact').trim().toLowerCase() !== 'false';
                }
                if (node === root) {
                    insideRoot = false;
                } else if (insideRoot && (skippedTags[node.tagName] || unseen(getComputedStyle(node)))) {
                    return true;
                }
            }
            return redacted === true;
        };
        // Displayed text, joined and capped at 100 characters like autocapture's target_text.
        const textOf = function (element) {
            if (element.tagName === 'INPUT' || skippedTags[element.tagName] || hidesText(element, element)) {
                return null;
            }
            const parts = [];
            const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
            let length = 0;
            for (let visited = 0; length < 100 && visited < 200 && walker.nextNode(); visited += 1) {
                const value = walker.currentNode.nodeValue;
                if (!value.trim() || hidesText(walker.currentNode.parentElement, element)) continue;
                parts.push(value);
                length += value.length;
            }
            const text = parts.join(' ').replace(/\s+/g, ' ').trim();
            return text ? text.slice(0, 100) : null;
        };
        const elements = [];
        document.querySelectorAll('[id], [data-userpilot-id]').forEach(function (element) {
            const userpilotId = element.getAttribute('data-userpilot-id') || null;
            const tag = element.id ? '#' + element.id : null;
            if (!userpilotId && !tag) return;
            const rect = element.getBoundingClientRect();
            if (rect.width <= 0 || rect.height <= 0) return;
            let left = offsetX, top = offsetY, right = offsetX + width, bottom = offsetY + height;
            // A transparent element stays on the visible screen, like a transparent native view.
            let opacity = 1;
            for (let parent = element; parent; parent = parent.parentElement) {
                const style = getComputedStyle(parent);
                if (hidden(style)) return;
                opacity *= Number(style.opacity);
                if (parent !== element) {
                    const clip = parent.getBoundingClientRect();
                    if (/hidden|clip|scroll|auto/.test(style.overflowX)) {
                        left = Math.max(left, clip.left); right = Math.min(right, clip.right);
                    }
                    if (/hidden|clip|scroll|auto/.test(style.overflowY)) {
                        top = Math.max(top, clip.top); bottom = Math.min(bottom, clip.bottom);
                    }
                }
            }
            const centerX = rect.left + rect.width / 2, centerY = rect.top + rect.height / 2;
            if (centerX < left || centerX >= right || centerY < top || centerY >= bottom) return;
            elements.push({x: Math.max(rect.left, left) - offsetX, y: Math.max(rect.top, top) - offsetY,
                width: Math.min(rect.right, right) - Math.max(rect.left, left),
                height: Math.min(rect.bottom, bottom) - Math.max(rect.top, top), userpilotId: userpilotId, tag: tag,
                text: textOf(element), transparent: opacity <= 0.01});
        });
        return {width: width, height: height, elements: elements};
    })
    """#
}
