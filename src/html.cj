package cjxt

let FRONTEND_JS = """
class CangjieUI {
    constructor(container, sessionId) {
        this.container = container;
        this.sessionId = sessionId;
        this.tree = null;
        this.ws = null;
    }
    init(tree) {
        this.tree = tree;
        this.renderTree(tree, this.container);
        this.connectWS();
    }
    connectWS() {
        const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
        this.ws = new WebSocket(proto + '//' + location.host + '/_ws');
        this.ws.onopen = () => this.send({ type: 'connect', sessionId: this.sessionId });
        this.ws.onmessage = (e) => this.handleMsg(JSON.parse(e.data));
        this.ws.onclose = () => setTimeout(() => this.connectWS(), 3000);
    }
    handleMsg(msg) {
        switch (msg.type) {
            case 'connected': this.ack('mount'); break;
            case 'patch':     this.applyPatches(msg.patches); this.ack('update'); break;
            case 'push':      this.applyPatches(msg.patches); break;
            case 'fullTree':  this.loadNewPage(msg); break;
        }
    }
    ack(event) { this.send({ type: 'ack', event: event, sessionId: this.sessionId }); }
    send(data) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN)
            this.ws.send(JSON.stringify(data));
    }
    loadNewPage(msg) {
        this.tree = msg.tree;
        this.container.innerHTML = '';
        this.renderTree(msg.tree, this.container);
        this.ack('mount');
    }
    renderTree(node, parentEl) {
        var el = document.createElement(node.type.toLowerCase());
        for (var k in node.attrs || {}) {
            if (k === 'text') { el.textContent = node.attrs[k]; continue; }
            el.setAttribute(k, node.attrs[k]);
        }
        for (var ev in node.actions || {}) {
            el.addEventListener(ev, (function(action) {
                return function(e) {
                    var params = {};
                    for (var a of el.attributes) {
                        if (a.name.startsWith('data-')) params[a.name.slice(5)] = a.value;
                    }
                    this.send({ type: 'action', name: action, params: params, sessionId: this.sessionId });
                }.bind(this);
            }).bind(this)(node.actions[ev]));
        }
        for (var child of node.children || []) this.renderTree(child, el);
        parentEl.appendChild(el);
    }
    applyPatches(patches) {
        for (var p of patches) {
            if (p.op === 'replace') { this.container.innerHTML = ''; this.renderTree(this.tree, this.container); break; }
        }
    }
}
"""

public func generateHtmlShell(sessionId: String): String {
    """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>cjxt</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    </style>
</head>
<body>
    <div id="app"></div>
    <script>
        var __SESSION_ID__ = "${sessionId}";
        var ui = new CangjieUI(document.getElementById('app'), __SESSION_ID__);
    </script>
    <script>
${FRONTEND_JS}
    </script>
</body>
</html>
"""
}
