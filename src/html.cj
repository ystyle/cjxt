package cjxt

import std.collection.HashMap

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
            case 'push':
                this.applyPatches(msg.patches);
                break;
            case 'title':
                document.title = msg.title;
                break;
            case 'deny':
                console.warn('Navigation denied:', msg.reason);
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
        if (type === 'style') {
            const el = document.createElement('style');
            el.textContent = node.attrs ? (node.attrs.text || '') : '';
            parentEl.appendChild(el);
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
        // 绑定 input 事件
        if (el.hasAttribute('data-bind-id')) this.attachBind(el);
    }
    attachBind(el) {
        const bid = el.getAttribute('data-bind-id');
        let timer = null;
        const send = () => {
            this.send({ type: 'bind', name: bid, value: el.value ?? el.textContent ?? '' });
        };
        el.addEventListener('input', () => {
            clearTimeout(timer);
            timer = setTimeout(send, 300);
            el.dataset.bindDirty = '1';
        });
        el.addEventListener('blur', () => {
            clearTimeout(timer);
            if (el.dataset.bindDirty) { send(); delete el.dataset.bindDirty; }
        });
        el.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') { clearTimeout(timer); send(); }
        });
    }
    applyPatches(patches) {
        // 保存焦点状态
        const activeEl = document.activeElement;
        const allInputs = Array.from(document.querySelectorAll('input,textarea'));
        const focusIdx = activeEl ? allInputs.indexOf(activeEl) : -1;
        const focusSelStart = activeEl ? activeEl.selectionStart : null;
        const focusSelEnd = activeEl ? activeEl.selectionEnd : null;
        if (activeEl) { delete activeEl.dataset.bindDirty; }

        for (const p of patches) {
            const parts = (p.path || '').split('/').filter(Boolean);
            if (parts.length === 0 && p.op === 'replace') {
                this.tree = p.value;
                this.container.innerHTML = '';
                this.renderTree(this.tree, this.container);
            } else {
                this.applyPatchToTree(this.tree, p.op, parts, p.value);
                this.applyPatchToDOM(this.container, p.op, parts, p.value);
            }
        }

        // 恢复焦点
        if (focusIdx >= 0) {
            const newInputs = document.querySelectorAll('input,textarea');
            if (focusIdx < newInputs.length) {
                const el = newInputs[focusIdx];
                el.focus();
                if (focusSelStart !== null && el.selectionStart !== undefined) {
                    el.selectionStart = focusSelStart;
                    el.selectionEnd = focusSelEnd ?? focusSelStart;
                }
            }
        }
    }
    applyPatchToTree(node, op, parts, value) {
        if (!node || parts.length === 0) return;
        if (parts[0] === 'attrs' && parts.length >= 2) {
            if (op === 'replace') {
                if (!node.attrs) node.attrs = {};
                node.attrs[parts[1]] = value;
            } else if (op === 'remove' && node.attrs) {
                delete node.attrs[parts[1]];
            }
        } else if (parts[0] === 'actions' && parts.length >= 2) {
            if (op === 'replace') {
                if (!node.actions) node.actions = {};
                node.actions[parts[1]] = value;
            } else if (op === 'remove' && node.actions) {
                delete node.actions[parts[1]];
            }
        } else if (parts[0] === 'children' && parts.length >= 2) {
            const idx = parseInt(parts[1]);
            if (op === 'add' && node.children) {
                node.children.splice(idx, 0, { type: 'div', attrs: {}, actions: null, children: [] });
            } else if (op === 'remove' && node.children) {
                node.children.splice(idx, 1);
            } else if (node.children && node.children[idx]) {
                this.applyPatchToTree(node.children[idx], op, parts.slice(2), value);
            }
        } else if (parts[0] === 'text' && op === 'replace') {
            if (!node.attrs) node.attrs = {};
            node.attrs.text = value;
        }
    }
    applyPatchToDOM(parent, op, parts, value) {
        let el = parent;
        let i = 0;
        while (i < parts.length && parts[i] === 'children' && i + 1 < parts.length) {
            const idx = parseInt(parts[i + 1]);
            if (el.childNodes && idx < el.childNodes.length) {
                el = el.childNodes[idx];
            } else { return; }
            i += 2;
        }
        if (i >= parts.length) return;
        if (el.nodeType === 3) {
            // text node — update textContent
            if (op === 'replace') el.textContent = value;
        } else if (parts[i] === 'attrs' && i + 1 < parts.length) {
            const attr = parts[i + 1];
            if (op === 'replace') el.setAttribute(attr, value);
            else if (op === 'remove') el.removeAttribute(attr);
        } else if (parts[i] === 'text' && op === 'replace') {
            el.textContent = value;
        }
    }
}
"""

func headTags(config: AppConfig): String {
    var html = ""
    html = "${html}    <title>${config.title}</title>\n"
    html = "${html}    <link rel=\"icon\" href=\"${config.favicon}\">\n"
    if (config.cssBundle != "") {
        html = "${html}    <link rel=\"stylesheet\" href=\"${config.cssBundle}\">\n"
    }
    for ((rel, href) in config.links) {
        html = "${html}    <link rel=\"${rel}\" href=\"${href}\">\n"
    }
    html
}

func scriptTags(config: AppConfig): String {
    var html = ""
    for (src in config.scripts) {
        html = "${html}    <script src=\"${src}\"></script>\n"
    }
    html
}

public func generateHtmlShell(sessionId: String, config!: AppConfig = AppConfig()): String {
    """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
${headTags(config)}    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: ${config.fontFamily}; }
    </style>
</head>
<body>
    <div id="app"></div>
    <script>
${FRONTEND_JS}
    </script>
${scriptTags(config)}    <script>
        var ui = new CangjieUI(document.getElementById('app'), "${sessionId}", null);
    </script>
</body>
</html>
"""
}
