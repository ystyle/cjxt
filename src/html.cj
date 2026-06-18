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
        this.attachClickDelegate();
        this.connectWS();
    }
    attachClickDelegate() {
        this.container.addEventListener('click', (e) => {
            const el = e.target.closest('[data-action-click]');
            if (!el) return;
            const name = el.getAttribute('data-action-click');
            const params = {};
            for (const a of el.attributes) {
                if (a.name.startsWith('data-') && !a.name.startsWith('data-action-')) params[a.name.slice(5)] = a.value;
            }
            this.send({ type: 'action', name, params, sessionId: this.sessionId });
        });
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
                if (msg.attrs && msg.attrs.length) this.applyStrPatches(msg.attrs);
                if (msg.trees && msg.trees.length) this.applyTreePatches(msg.trees);
                this.send({ type: 'ack', event: 'update', sessionId: this.sessionId });
                break;
            case 'push':
                if (msg.attrs && msg.attrs.length) this.applyStrPatches(msg.attrs);
                if (msg.trees && msg.trees.length) this.applyTreePatches(msg.trees);
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
    createElement(type) {
        const svgTags = { svg: 1, path: 1, circle: 1, rect: 1, line: 1, polyline: 1, polygon: 1, ellipse: 1, g: 1, defs: 1, use: 1, text: 1, tspan: 1 };
        if (svgTags[type]) {
            return document.createElementNS('http://www.w3.org/2000/svg', type);
        }
        return document.createElement(type);
    }
    loadNewPage(msg) {
        this.tree = msg.tree;
        this.container.innerHTML = '';
        this.renderTree(this.tree, this.container);
        this.send({ type: 'ack', event: 'mount', sessionId: this.sessionId });
    }
    renderTree(node, parentEl) {
        const type = (node.type || '').toLowerCase();
        if (type === 'fragment') {
            (node.children || []).forEach(c => this.renderTree(c, parentEl));
            return;
        }
        if (type === 'empty') return;
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
        const el = this.createElement(type);
        for (const k in node.attrs || {}) {
            if (k === 'text') continue;
            if (k === 'value') { el.value = node.attrs[k]; continue; }
            el.setAttribute(k, node.attrs[k]);
        }
        for (const ev in node.actions || {}) {
            const action = node.actions[ev];
            el.setAttribute(`data-action-\${ev}`, action);
            if (ev !== 'click') {
                el.addEventListener(ev, (e) => {
                    const name = el.getAttribute(`data-action-\${ev}`);
                    if (!name) return;
                    const params = {};
                    for (const a of el.attributes) {
                        if (a.name.startsWith('data-') && !a.name.startsWith('data-action-')) params[a.name.slice(5)] = a.value;
                    }
                    this.send({ type: 'action', name, params, sessionId: this.sessionId });
                });
            }
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
    applyStrPatches(patches) {
        const activeEl = document.activeElement;
        const allInputs = Array.from(document.querySelectorAll('input,textarea'));
        const focusIdx = activeEl ? allInputs.indexOf(activeEl) : -1;
        const focusSelStart = activeEl ? activeEl.selectionStart : null;
        const focusSelEnd = activeEl ? activeEl.selectionEnd : null;
        if (activeEl) { delete activeEl.dataset.bindDirty; }

        for (const p of patches) {
            const parts = (p.path || '').split('/').filter(Boolean);
            this.applyPatchToTree(this.tree, p.op, parts, p.value);
            this.applyPatchToDOM(this.container, p.op, parts, p.value);
        }

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
    applyTreePatches(trees) {
        const sortedTrees = [...trees].sort((a, b) => {
            const partsA = (a.path || '').split('/').filter(Boolean);
            const partsB = (b.path || '').split('/').filter(Boolean);
            const minLen = Math.min(partsA.length, partsB.length);
            for (let i = 0; i < minLen - 1; i++) {
                if (partsA[i] !== partsB[i]) return partsA[i].localeCompare(partsB[i]);
            }
            const idxA = parseInt(partsA[partsA.length - 1]);
            const idxB = parseInt(partsB[partsB.length - 1]);
            return idxB - idxA;
        });
        for (const p of sortedTrees) {
            const parts = (p.path || '').split('/').filter(Boolean);
            if (parts.length === 0) {
                if (p.op === 'replace' && p.tree) {
                    this.tree = p.tree;
                    this.container.innerHTML = '';
                    this.renderTree(this.tree, this.container);
                }
                continue;
            }
            this.applyPatchToTree(this.tree, p.op, parts, p.tree);
            const parentParts = parts.slice(0, -2);
            const parentEl = parentParts.length ? this.navigateTo(parentParts, this.container) : this.container;
            if (!parentEl) continue;
            const idx = parseInt(parts[parts.length - 1]);
            if (p.op === 'replace' && p.tree) {
                const old = parentEl.childNodes[idx];
                if (old) {
                    const newEl = this.renderSubtree(p.tree);
                    if (newEl) parentEl.replaceChild(newEl, old);
                }
            } else if (p.op === 'add' && p.tree) {
                const newEl = this.renderSubtree(p.tree);
                if (!newEl) continue;
                if (idx < parentEl.childNodes.length) {
                    parentEl.insertBefore(newEl, parentEl.childNodes[idx]);
                } else {
                    parentEl.appendChild(newEl);
                }
            } else if (p.op === 'remove') {
                const old = parentEl.childNodes[idx];
                if (old) old.parentNode.removeChild(old);
            }
        }
    }
    navigateTo(parts, parent) {
        let el = parent.firstElementChild;
        if (!el) return null;
        let i = 0;
        while (i < parts.length && parts[i] === 'children' && i + 1 < parts.length) {
            const idx = parseInt(parts[i + 1]);
            const children = el.childNodes;
            if (children && idx < children.length) {
                el = children[idx];
            } else { return null; }
            i += 2;
        }
        return (i >= parts.length) ? el : null;
    }
    renderSubtree(node) {
        const type = (node.type || '').toLowerCase();
        if (type === 'fragment') {
            const wrapper = document.createDocumentFragment();
            (node.children || []).forEach(c => wrapper.appendChild(this.renderSubtree(c)));
            return wrapper;
        }
        if (type === 'empty') return null;
        if (type === 'text') {
            return document.createTextNode(node.attrs ? (node.attrs.text || '') : '');
        }
        if (type === 'style') {
            const el = document.createElement('style');
            el.textContent = node.attrs ? (node.attrs.text || '') : '';
            return el;
        }
        const el = this.createElement(type);
        for (const k in node.attrs || {}) {
            if (k === 'text') continue;
            if (k === 'value') { el.value = node.attrs[k]; continue; }
            el.setAttribute(k, node.attrs[k]);
        }
        for (const ev in node.actions || {}) {
            const action = node.actions[ev];
            el.setAttribute(`data-action-\${ev}`, action);
            if (ev !== 'click') {
                el.addEventListener(ev, (e) => {
                    const name = el.getAttribute(`data-action-\${ev}`);
                    if (!name) return;
                    const params = {};
                    for (const a of el.attributes) {
                        if (a.name.startsWith('data-') && !a.name.startsWith('data-action-')) params[a.name.slice(5)] = a.value;
                    }
                    this.send({ type: 'action', name, params, sessionId: this.sessionId });
                });
            }
        }
        for (const child of node.children || []) el.appendChild(this.renderSubtree(child));
        if (el.hasAttribute('data-bind-id')) this.attachBind(el);
        return el;
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
            if (op === 'add' && parts.length === 2 && node.children) {
                node.children.splice(idx, 0, value || { type: 'div', attrs: {}, actions: null, children: [] });
            } else if (op === 'replace' && node.children && node.children[idx] && parts.length == 2) {
                node.children[idx] = value;
            } else if (op === 'remove' && parts.length === 2 && node.children) {
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
        let el = parent.firstElementChild;
        if (!el) return;
        let i = 0;
        while (i < parts.length && parts[i] === 'children' && i + 1 < parts.length) {
            const idx = parseInt(parts[i + 1]);
            const children = el.childNodes;
            if (children && idx < children.length) {
                el = children[idx];
            } else { return; }
            i += 2;
        }
        if (i >= parts.length) {
            if (op === 'remove' && el.parentNode) {
                el.parentNode.removeChild(el);
            }
            return;
        }
        if (el.nodeType === 3) {
            if (op === 'replace') el.textContent = value;
        } else if (parts[i] === 'attrs' && i + 1 < parts.length) {
            const attr = parts[i + 1];
            if (attr === 'value') {
                if (op === 'replace') el.value = value;
                else if (op === 'remove') el.value = '';
            } else if (op === 'replace') {
                el.setAttribute(attr, value);
            } else if (op === 'remove') {
                el.removeAttribute(attr);
            }
        } else if (parts[i] === 'actions' && i + 1 < parts.length) {
            const ev = parts[i + 1];
            if (op === 'replace') el.setAttribute(`data-action-\${ev}`, value);
            else if (op === 'remove') el.removeAttribute(`data-action-\${ev}`);
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
    if (config.componentsCss != "") {
        html = "${html}    <link rel=\"stylesheet\" href=\"${config.componentsCss}\">\n"
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
