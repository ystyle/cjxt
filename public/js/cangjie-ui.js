class CangjieUI {
    constructor(container, sessionId, initialTree) {
        this.container = container;
        this.sessionId = sessionId;
        this.tree = initialTree;
        this.ws = null;
        this.init();
        window.CJXT = { registerComponent: this.registerComponent.bind(this) };
    }
    init() {
        if (this.tree) this.renderTree(this.tree, this.container);
        this.attachClickDelegate();
        this.attachKeyDelegate();
        this.attachHistoryHandler();
        this.connectWS();
    }
    attachKeyDelegate() {
        this.attachKeyEvent('keydown');
        this.attachKeyEvent('keyup');
    }
    attachKeyEvent(type) {
        this.container.addEventListener(type, (e) => {
            const el = e.target.closest('[data-action-keydown],[data-action-keyup],[data-action-keydown_enter]');
            if (!el) return;
            let name = null;
            if (type === 'keydown') {
                const kd = el.getAttribute('data-action-keydown');
                if (kd) {
                    name = kd;
                } else {
                    const enter = el.getAttribute('data-action-keydown_enter');
                    if (enter && e.key === 'Enter') name = enter;
                }
            } else {
                name = el.getAttribute('data-action-keyup');
            }
            if (!name) return;
            // keydown_enter 是显式回车命令：阻止默认行为（避免触发表单提交等）；
            // 通用 keydown 不 preventDefault，否则会破坏输入（backspace/字符键）。
            if (type === 'keydown' && !el.getAttribute('data-action-keydown')) e.preventDefault();
            const params = this.collectParams(el);
            params.key = e.key;
            params.code = e.code;
            params.keyCode = String(e.keyCode);
            params.ctrl = e.ctrlKey ? '1' : '0';
            params.shift = e.shiftKey ? '1' : '0';
            params.alt = e.altKey ? '1' : '0';
            params.meta = e.metaKey ? '1' : '0';
            this.send({ type: 'action', name, params, sessionId: this.sessionId });
        });
    }
    collectParams(el) {
        const params = {};
        for (const a of el.attributes) {
            if (a.name.startsWith('data-') && !a.name.startsWith('data-action-')) params[a.name.slice(5)] = a.value;
        }
        // 表单控件（input/select/textarea）额外带上当前值，供 action 处理
        const tag = el.tagName;
        if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') {
            params.value = el.value !== undefined && el.value !== null ? String(el.value) : '';
        }
        return params;
    }
    attachHistoryHandler() {
        window.addEventListener('popstate', () => {
            const path = window.location.pathname;
            this.send({ type: 'navigate', path, sessionId: this.sessionId });
        });
    }
    attachClickDelegate() {
        this.container.addEventListener('click', (e) => {
            const el = e.target.closest('[data-action-click]');
            if (!el) return;
            const name = el.getAttribute('data-action-click');
            this.send({ type: 'action', name, params: this.collectParams(el), sessionId: this.sessionId });
        });
    }
    connectWS() {
        const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
        this.ws = new WebSocket(proto + '//' + location.host + '/ws');
        this.ws.onopen = () => this.send({ type: 'connect', sessionId: this.sessionId, token: localStorage.getItem('cjxt_token') || '' });
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
                if (msg.trees && msg.trees.length) this.applyTreePatches(msg.trees);
                this.send({ type: 'ack', event: 'update', sessionId: this.sessionId });
                break;
            case 'push':
                if (msg.trees && msg.trees.length) this.applyTreePatches(msg.trees);
                break;
            case 'title':
                document.title = msg.title;
                break;
            case 'dom_command':
                this.execDomCommands(msg);
                break;
            case 'deny':
                console.warn('Navigation denied:', msg.reason);
                if (msg.path) {
                    this.send({ type: 'navigate', path: msg.path, sessionId: this.sessionId });
                }
                break;
            case 'auth':
                if (msg.token) localStorage.setItem('cjxt_token', msg.token);
                else localStorage.removeItem('cjxt_token');
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
        if (msg.path) {
            history.pushState(null, '', msg.path);
        }
        this.send({ type: 'ack', event: 'mount', sessionId: this.sessionId });
    }
    renderTree(node, parentEl) {
        const type = (node.type || '').toLowerCase();
        if (type === 'fragment') {
            (node.children || []).forEach(c => this.renderTree(c, parentEl));
            return;
        }
        if (type === 'empty') {
            // 空节点必须占 DOM 槽位：树路径按 children 索引定位 DOM，
            // 若 empty 不产生节点，后续 patch（如 Dialog 打开/关闭）的
            // 路径定位会错位——打开时定位失败、关闭时旧 DOM 残留遮罩。
            parentEl.appendChild(this.makeEmptySlot());
            return;
        }
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
        if (type.startsWith('client:')) {
            this.renderClientComponent(node, parentEl);
            return;
        }
        const el = this.createElement(type);
        for (const k in node.attrs || {}) {
            if (k === 'text') continue;
            if (k === 'value') { el.value = node.attrs[k]; continue; }
            if (k.toLowerCase() === 'innerhtml') { el.innerHTML = node.attrs[k]; continue; }
            el.setAttribute(k, node.attrs[k]);
        }
        for (const ev in node.actions || {}) {
            const action = node.actions[ev];
            el.setAttribute('data-action-' + ev, action);
            if (ev !== 'click' && ev !== 'keydown' && ev !== 'keyup' && ev !== 'keydown_enter') {
                el.addEventListener(ev, (e) => {
                    const name = el.getAttribute('data-action-' + ev);
                    if (!name) return;
                    this.send({ type: 'action', name, params: this.collectParams(el), sessionId: this.sessionId });
                });
            }
        }
        for (const child of node.children || []) this.renderTree(child, el);
        parentEl.appendChild(el);
        // 绑定 input 事件
        if (el.hasAttribute('data-bind-id')) this.attachBind(el);
        if (el.hasAttribute('data-vscroll')) this.attachVScroll(el);
        // 自动消失（Message/Notification 等）：data-auto-dismiss="ms" → 到时触发点击（关闭 action）
        if (el.hasAttribute('data-auto-dismiss')) this.attachAutoDismiss(el);
        // 上传：data-upload-trigger（点触发 file input）+ data-upload-input（change 后 XHR 上传）
        if (el.hasAttribute('data-upload-trigger') || el.hasAttribute('data-upload-input')) this.attachUpload(el);
    }

    // ============ keyed reconciliation：原位更新 DOM，只改变化部分，避免全量重建（补丁粒度细化 P2#1） ============

    // 从 node 新建 DOM 节点（插入/替换用）
    createNode(node) {
        const type = (node.type || '').toLowerCase();
        if (type === 'fragment') {
            const wrapper = document.createDocumentFragment();
            for (const c of (node.children || [])) wrapper.appendChild(this.createNode(c));
            return wrapper;
        }
        if (type === 'empty') return this.makeEmptySlot();
        if (type === 'text') return document.createTextNode(node.attrs ? (node.attrs.text || '') : '');
        if (type === 'style') {
            const el = document.createElement('style');
            el.textContent = node.attrs ? (node.attrs.text || '') : '';
            return el;
        }
        if (type.startsWith('client:')) {
            const wrapper = document.createElement('div');
            this.renderClientComponent(node, wrapper);
            return wrapper.firstElementChild || wrapper;
        }
        const el = this.createElement(type);
        this.applyAttrs(el, node);
        this.applyActions(el, node);
        for (const c of (node.children || [])) el.appendChild(this.createNode(c));
        if (el.hasAttribute('data-bind-id')) this.attachBind(el);
        if (el.hasAttribute('data-vscroll')) this.attachVScroll(el);
        if (el.hasAttribute('data-auto-dismiss')) this.attachAutoDismiss(el);
        if (el.hasAttribute('data-upload-trigger') || el.hasAttribute('data-upload-input')) this.attachUpload(el);
        return el;
    }

    // 设置元素属性（新建/reconcile 通用；bound input 的 value 更新走守卫，避免打断输入）
    applyAttrs(el, node) {
        const attrs = node.attrs || {};
        for (const a of Array.from(el.attributes)) {
            const n = a.name;
            if (n in attrs) continue;
            if (n === 'value') continue;
            if (n.startsWith('data-')) continue; // data-* 由 actions/bind 等管理
            el.removeAttribute(n);
        }
        for (const k in attrs) {
            if (k === 'text') continue;
            if (k === 'value') {
                const composing = el.dataset.composing === '1';
                const dirty = el.dataset.bindDirty === '1';
                if (!composing && !dirty && el.value !== attrs[k]) el.value = attrs[k];
                continue;
            }
            if (k.toLowerCase() === 'innerhtml') {
                if (el.innerHTML !== attrs[k]) el.innerHTML = attrs[k];
                continue;
            }
            if (el.getAttribute(k) !== attrs[k]) el.setAttribute(k, attrs[k]);
        }
    }

    // 同步 data-action-* 与每元素监听器
    applyActions(el, node) {
        for (const a of Array.from(el.attributes)) {
            if (a.name.startsWith('data-action-')) el.removeAttribute(a.name);
        }
        for (const ev in (node.actions || {})) {
            const action = node.actions[ev];
            el.setAttribute('data-action-' + ev, action);
            if (ev !== 'click' && ev !== 'keydown' && ev !== 'keyup' && ev !== 'keydown_enter') {
                if (!el['__cjxtL_' + ev]) {
                    el.addEventListener(ev, (e) => {
                        const name = el.getAttribute('data-action-' + ev);
                        if (!name) return;
                        this.send({ type: 'action', name, params: this.collectParams(el), sessionId: this.sessionId });
                    });
                    el['__cjxtL_' + ev] = true;
                }
            }
        }
    }

    // 现有 DOM 节点能否复用来匹配 tree node
    matchesNode(el, node) {
        const rawType = node.type || '';
        const type = rawType.toLowerCase();
        if (type === 'fragment') return false;
        if (type === 'empty') return !!(el.dataset && el.dataset.cjxtEmpty === '1');
        if (type === 'text') return el.nodeType === 3;
        if (type === 'style') return el.nodeType === 1 && el.tagName === 'STYLE';
        if (type.startsWith('client:')) {
            // 组件名大小写敏感（client:Tooltip），用原始 type 取组件名
            return el.__cjxtCompName === rawType.slice(7);
        }
        return el.nodeType === 1 && el.tagName === type.toUpperCase();
    }

    // 原位更新已有元素 el 以匹配 node（tag 一致由 matchesNode 保证）
    reconcileNode(el, node) {
        const type = (node.type || '').toLowerCase();
        if (type === 'text') {
            const t = node.attrs ? (node.attrs.text || '') : '';
            if (el.textContent !== t) el.textContent = t;
            return;
        }
        if (type === 'style') {
            const t = node.attrs ? (node.attrs.text || '') : '';
            if (el.textContent !== t) el.textContent = t;
            return;
        }
        if (type === 'empty') return;
        if (type.startsWith('client:')) {
            // 客户端组件：原位复用实例，调 update() 同步 props（保留瞬时 UI 状态）
            if (el.__cjxtComp && typeof el.__cjxtComp.update === 'function') {
                el.__cjxtComp.update(node.props || {}, el);
            }
            this.applyActions(el, node);
            return;
        }
        this.applyAttrs(el, node);
        this.applyActions(el, node);
        this.reconcileChildren(el, node.children || []);
        if (el.hasAttribute('data-bind-id') && !el.__cjxtBound) { this.attachBind(el); el.__cjxtBound = true; }
        if (el.hasAttribute('data-vscroll') && !el.__cjxtVScroll) { this.attachVScroll(el); el.__cjxtVScroll = true; }
        if (el.hasAttribute('data-auto-dismiss') && !el.__cjxtAutoDismiss) { this.attachAutoDismiss(el); el.__cjxtAutoDismiss = true; }
        if ((el.hasAttribute('data-upload-trigger') || el.hasAttribute('data-upload-input')) && !el.__cjxtUpload) { this.attachUpload(el); el.__cjxtUpload = true; }
    }

    // 上传：触发区点击 → 打开 file input；file change → XHR multipart 上传 → 成功后按
    // data-action-uploaded（稳定 handler id）dispatch action（服务端 handler 加文件到列表）
    attachUpload(el) {
        if (el.hasAttribute('data-upload-trigger') && !el.__cjxtUploadTrigger) {
            el.__cjxtUploadTrigger = true;
            el.addEventListener('click', (ev) => {
                ev.preventDefault();
                const input = el.parentElement && el.parentElement.querySelector('[data-upload-input]');
                if (input) input.click();
            });
        }
        if (el.hasAttribute('data-upload-input') && !el.__cjxtUploadInput) {
            el.__cjxtUploadInput = true;
            el.addEventListener('change', () => {
                const file = el.files && el.files[0];
                if (!file) return;
                const url = el.getAttribute('data-upload');
                const action = el.getAttribute('data-action-uploaded');
                if (!url || !action) return;
                // FileReader → base64 data URL → POST JSON（绕开 multipart 服务端解析问题）
                const reader = new FileReader();
                reader.onload = () => {
                    const dataUrl = String(reader.result || '');
                    const comma = dataUrl.indexOf(',');
                    const b64 = comma >= 0 ? dataUrl.slice(comma + 1) : dataUrl;
                    const xhr = new XMLHttpRequest();
                    xhr.open('POST', url);
                    xhr.setRequestHeader('Content-Type', 'application/json');
                    xhr.onload = () => {
                        let res = {};
                        try { res = JSON.parse(xhr.responseText); } catch (e) {}
                        if (window.ui) {
                            window.ui.send({
                                type: 'action',
                                name: action,
                                params: {
                                    name: res.name || file.name,
                                    url: res.url || '',
                                    size: String(res.size != null ? res.size : file.size)
                                },
                                sessionId: window.ui.sessionId
                            });
                        }
                    };
                    xhr.onerror = () => {};
                    xhr.send(JSON.stringify({ name: file.name, data: b64 }));
                };
                reader.onerror = () => {};
                reader.readAsDataURL(file);
                el.value = ''; // 允许重复选同一文件
            });
        }
    }

    // 将 nodes 序列 reconcile 到 parentEl 的现有子节点（位置对齐 + 复用；fragment 先平铺）
    reconcileChildren(parentEl, nodes) {
        const flat = [];
        const flatten = (list) => {
            for (const n of list) {
                if ((n.type || '').toLowerCase() === 'fragment') flatten(n.children || []);
                else flat.push(n);
            }
        };
        flatten(nodes);
        const existing = Array.from(parentEl.childNodes);
        let e = 0;
        for (let i = 0; i < flat.length; i++) {
            const node = flat[i];
            let target = existing[e];
            if (!target) {
                const el = this.createNode(node);
                if (el) parentEl.appendChild(el);
                e++;
                continue;
            }
            if (this.matchesNode(target, node)) {
                this.reconcileNode(target, node);
                e++;
            } else {
                const el = this.createNode(node);
                if (el) {
                    const oldComp = target.__cjxtComp;
                    if (oldComp && typeof oldComp.destroy === 'function') oldComp.destroy(target);
                    parentEl.replaceChild(el, target);
                }
                existing[e] = el || null;
                e++;
            }
        }
        while (existing.length > e) {
            const extra = existing[existing.length - 1];
            const oldComp = extra && extra.__cjxtComp;
            if (oldComp && typeof oldComp.destroy === 'function') oldComp.destroy(extra);
            if (extra && extra.parentNode === parentEl) parentEl.removeChild(extra);
            existing.pop();
        }
    }
    attachAutoDismiss(el) {
        const ms = parseInt(el.getAttribute('data-auto-dismiss'), 10);
        if (!ms || ms <= 0) return;
        setTimeout(() => {
            if (el.isConnected) el.dispatchEvent(new MouseEvent('click', { bubbles: true }));
        }, ms);
    }
    attachBind(el) {
        const bid = el.getAttribute('data-bind-id');
        let timer = null;
        let composing = false;
        const send = () => {
            if (composing) return;
            const raw = el.value ?? el.textContent ?? '';
            const value = el.type === 'range' ? parseFloat(raw) : raw;
            this.send({ type: 'bind', name: bid, value });
        };
        el.addEventListener('compositionstart', () => { composing = true; el.dataset.composing = '1'; });
        el.addEventListener('compositionend', () => {
            composing = false;
            delete el.dataset.composing;
            clearTimeout(timer);
            timer = setTimeout(send, 300);
        });
        el.addEventListener('input', () => {
            if (composing) return;
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
    // 虚拟滚动容器：rAF 节流上报 scrollTop（通过 bind 消息，value=scrollTop）
    attachVScroll(el) {
        const bid = el.getAttribute('data-bind-id');
        if (!bid) return;
        let raf = null;
        el.addEventListener('scroll', () => {
            if (raf) return;
            raf = requestAnimationFrame(() => {
                raf = null;
                this.send({ type: 'bind', name: bid, value: String(el.scrollTop) });
            });
        });
    }
    registerComponent(name, compClass) {
        window.__CJXT_COMPONENTS__ = window.__CJXT_COMPONENTS__ || {};
        window.__CJXT_COMPONENTS__[name] = compClass;
    }
    getComponent(name) {
        return (window.__CJXT_COMPONENTS__ || {})[name];
    }
    renderClientComponent(node, parentEl) {
        const compName = node.type.slice(7);
        const CompClass = (window.__CJXT_COMPONENTS__ || {})[compName];
        if (!CompClass) {
            node._retries = (node._retries || 0) + 1;
            if (node._retries > 3) {
                console.error('cjxt: Client component "' + compName + '" not registered after 3 attempts. Props:', node.props, 'Actions:', node.actions);
                const el = document.createElement('div');
                el.style.cssText = 'color:#999;font-size:12px;padding:4px;border:1px dashed #ddd;';
                el.textContent = '组件 [' + compName + '] 加载失败';
                parentEl.appendChild(el);
                return;
            }
            console.warn('cjxt: Client component not registered:', compName, '(attempt ' + node._retries + '/3)');
            return;
        }
        const comp = new CompClass();
        const el = comp.create(node.props || {}, parentEl);
        el.__cjxtComp = comp;
        el.__cjxtCompName = compName;
        // 将 actions（事件名 → handler ID）设到 DOM 上，通过标准 action 派发
        for (const ev in node.actions || {}) {
            el.setAttribute('data-action-' + ev, node.actions[ev]);
        }
    }
    applyTreePatches(trees) {
        const activeEl = document.activeElement;
        const allInputs = Array.from(document.querySelectorAll('input,textarea'));
        const focusIdx = activeEl ? allInputs.indexOf(activeEl) : -1;
        const focusSelStart = activeEl ? activeEl.selectionStart : null;
        const focusSelEnd = activeEl ? activeEl.selectionEnd : null;

        for (const p of trees) {
            const parts = (p.path || '').split('/').filter(Boolean);
            if (parts.length === 0) {
                if (p.op === 'replace' && p.tree) {
                    // 整页替换：keyed reconciliation 原位更新，保留根元素与匹配后代
                    // （焦点/滚动/IME 不丢失，只改变化部分——流式/大数据不再整页重建）
                    this.tree = p.tree;
                    this.reconcileChildren(this.container, [p.tree]);
                }
                continue;
            }
            const parentParts = parts.slice(0, -2);
            const parentEl = parentParts.length ? this.navigateTo(parentParts, this.container) : this.container;
            if (!parentEl) continue;
            const idx = parseInt(parts[parts.length - 1]);
            if (p.op === 'replace' && p.tree) {
                const old = parentEl.childNodes[idx];
                if (old) {
                    if (this.matchesNode(old, p.tree)) {
                        // 同类型：原位 reconcile（含 bound input 的 value 守卫，保留 IME/焦点）
                        this.reconcileNode(old, p.tree);
                    } else {
                        // 类型不匹配：替换前销毁旧的 client 组件
                        const oldComp = old.__cjxtComp;
                        if (oldComp && typeof oldComp.destroy === 'function') oldComp.destroy(old);
                        const newEl = this.createNode(p.tree);
                        if (newEl) parentEl.replaceChild(newEl, old);
                    }
                }
            }
        }

        // 补丁应用完成：输入已与服务端同步，清除 dirty 标记
        if (activeEl) { delete activeEl.dataset.bindDirty; }

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

        // 自动滚动（data-auto-scroll）：内容更新后贴底跟随（仅当用户接近底部时，避免打断回看）
        this.autoScrollAll();
    }
    autoScrollAll() {
        document.querySelectorAll('[data-auto-scroll]').forEach((el) => {
            const dist = el.scrollHeight - el.scrollTop - el.clientHeight;
            if (dist < 80) el.scrollTop = el.scrollHeight;
        });
    }
    // DOM 事务执行器（事件驱动）：执行服务端下发的 dom_command，needResult 时回 dom_result
    execDomCommands(msg) {
        const results = {};
        const cmds = msg.commands || [];
        for (const cmd of cmds) {
            const parts = (cmd.path || '').split('/').filter(Boolean);
            const el = parts.length ? this.navigateTo(parts, this.container) : this.container;
            if (!el) continue;
            switch (cmd.cmd) {
                case 'focus':
                    el.focus();
                    break;
                case 'scrollIntoView':
                    el.scrollIntoView({ behavior: cmd.value || 'smooth', block: 'nearest' });
                    break;
                case 'setProperty':
                    if (cmd.property) el[cmd.property] = cmd.value || '';
                    break;
                case 'getProperty':
                    if (cmd.resultKey && cmd.property !== undefined) {
                        results[cmd.resultKey] = String(el[cmd.property] ?? '');
                    }
                    break;
            }
        }
        if (msg.needResult) {
            this.send({ type: 'dom_result', txId: msg.txId, results, sessionId: this.sessionId });
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
    makeEmptySlot() {
        const el = document.createElement('span');
        el.style.display = 'none';
        el.dataset.cjxtEmpty = '1';
        return el;
    }
    renderSubtree(node) {
        const type = (node.type || '').toLowerCase();
        if (type === 'fragment') {
            const wrapper = document.createDocumentFragment();
            (node.children || []).forEach(c => wrapper.appendChild(this.renderSubtree(c)));
            return wrapper;
        }
        if (type === 'empty') return this.makeEmptySlot();
        if (type === 'text') {
            return document.createTextNode(node.attrs ? (node.attrs.text || '') : '');
        }
        if (type === 'style') {
            const el = document.createElement('style');
            el.textContent = node.attrs ? (node.attrs.text || '') : '';
            return el;
        }
        if (type.startsWith('client:')) {
            const wrapper = document.createElement('div');
            this.renderClientComponent(node, wrapper);
            return wrapper;
        }
        const el = this.createElement(type);
        for (const k in node.attrs || {}) {
            if (k === 'text') continue;
            if (k === 'value') { el.value = node.attrs[k]; continue; }
            if (k.toLowerCase() === 'innerhtml') { el.innerHTML = node.attrs[k]; continue; }
            el.setAttribute(k, node.attrs[k]);
        }
        for (const ev in node.actions || {}) {
            const action = node.actions[ev];
            el.setAttribute('data-action-' + ev, action);
            if (ev !== 'click' && ev !== 'keydown' && ev !== 'keyup' && ev !== 'keydown_enter') {
                el.addEventListener(ev, (e) => {
                    const name = el.getAttribute('data-action-' + ev);
                    if (!name) return;
                    this.send({ type: 'action', name, params: this.collectParams(el), sessionId: this.sessionId });
                });
            }
        }
        for (const child of node.children || []) el.appendChild(this.renderSubtree(child));
        if (el.hasAttribute('data-bind-id')) this.attachBind(el);
        if (el.hasAttribute('data-auto-dismiss')) this.attachAutoDismiss(el);
        return el;
    }
}
