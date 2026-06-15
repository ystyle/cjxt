package cjxt

let FRONTEND_JS = """
class CangjieUI {
    constructor(container, sessionId, initialTree) {
        this.container = container;
        this.sessionId = sessionId;
        this.tree = initialTree;
        this.ws = null;
        this.init();
    }
    init() {
        if (this.tree) this.renderTree(this.tree, this.container);
        this.connectWS();
    }
    connectWS() {
        const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
        this.ws = new WebSocket(proto + '//' + location.host + '/ws');
        this.ws.onopen = () => this.send({ type: 'connect', sessionId: this.sessionId });
        this.ws.onmessage = (e) => {
            try {
                this.handleMsg(JSON.parse(e.data));
            } catch(err) {
                console.error('cjxt WS error:', err.message, 'data:', e.data.substring(0,200));
            }
        };
        this.ws.onclose = () => setTimeout(() => this.connectWS(), 3000);
    }
    handleMsg(msg) {
        switch (msg.kind) {
            case 'connected':
                this.send({ type: 'ack', event: 'mount', sessionId: this.sessionId });
                break;
            case 'patch':
                this.applyPatches(msg.patches);
                this.send({ type: 'ack', event: 'update', sessionId: this.sessionId });
                break;
            case 'fullTree':
                this.loadNewPage(msg);
                break;
        }
    }
    send(data) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN)
            this.ws.send(JSON.stringify(data));
    }
    loadNewPage(msg) {
        this.tree = msg.tree;
        this.container.innerHTML = '';
        this.renderTree(this.tree, this.container);
        this.send({ type: 'ack', event: 'mount', sessionId: this.sessionId });
    }
    renderTree(node, parentEl) {
        const type = (node.type || '').toLowerCase();
        if (type === 'text') {
            parentEl.appendChild(document.createTextNode(node.attrs ? (node.attrs.text || '') : ''));
            return;
        }
        const el = document.createElement(type);
        for (const k in node.attrs || {}) {
            if (k === 'text') continue;
            el.setAttribute(k, node.attrs[k]);
        }
        for (const ev in node.actions || {}) {
            const action = node.actions[ev];
            el.addEventListener(ev, (e) => {
                const params = {};
                for (const a of el.attributes) {
                    if (a.name.startsWith('data-')) params[a.name.slice(5)] = a.value;
                }
                this.send({ type: 'action', name: action, params, sessionId: this.sessionId });
            });
        }
        for (const child of node.children || []) this.renderTree(child, el);
        parentEl.appendChild(el);
    }
    applyPatches(patches) {
        for (const p of patches) {
            if (p.op === 'replace') {
                const path = p.path || '';
                const parts = path.split('/').filter(Boolean);
                if (parts.length === 0) {
                    this.tree = p.value;
                    this.container.innerHTML = '';
                    this.renderTree(this.tree, this.container);
                }
            }
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
${FRONTEND_JS}
    </script>
    <script>
        var ui = new CangjieUI(document.getElementById('app'), "${sessionId}", null);
    </script>
</body>
</html>
"""
}
