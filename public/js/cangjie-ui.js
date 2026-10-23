/**
 * WebSocket 承载（默认）：连 `location.host` 的 `/ws`。
 *
 * 会话 id 由页面提供；连上后发 connect 帧（带 localStorage 里的令牌）。
 * 断线每 3 秒重连——服务端重启/换实例后页面能自愈。
 */
class WebSocketTransport {
    constructor(ui, opts) {
        this.ui = ui;
        this.opts = opts || {};
        this.ws = null;
        this.opened = false;
    }
    connect() {
        const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
        const url = this.opts.url || (proto + '//' + location.host + '/ws');
        this.ws = new WebSocket(url);
        this.ws.binaryType = 'arraybuffer';
        this.ws.onopen = () => {
            this.opened = true;
            this.ui.send({ type: 'connect', sessionId: this.ui.sessionId, token: localStorage.getItem('cjxt_token') || '' });
        };
        this.ws.onmessage = (e) => {
            try {
                const msg = JSON.parse(e.data);
                // 上传协议帧（进度 ack / 错误）：独立路由，不进入页面 message 处理
                if (msg.kind === 'upload_progress' || msg.kind === 'upload_error') {
                    this.ui.handleUploadMsg(msg);
                    return;
                }
                this.ui.handleMsg(msg);
            } catch (err) {
                console.error('cjxt WS error:', err.message, 'data:', typeof e.data === 'string' ? e.data.substring(0, 200) : '(binary)');
            }
        };
        this.ws.onclose = () => {
            this.opened = false;
            for (const [, w] of this.ui._uploadWaiters) w.rej(new Error('connection closed'));
            this.ui._uploadWaiters.clear();
            setTimeout(() => this.connect(), 3000);
        };
    }
    send(data) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(data));
            return true;
        }
        return false;
    }
    sendBinary(buf) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(buf);
            return true;
        }
        return false;
    }
    get isOpen() {
        return !!(this.ws && this.ws.readyState === WebSocket.OPEN);
    }
}

/**
 * 宿主绑定承载：页面不连任何 socket，出站消息交给宿主提供的 send 函数，
 * 入站消息由宿主调 `ui.receive(text)` 送回来。
 *
 * 具体桥对象名与调用约定由承载方决定（框架不假定任何具体宿主）；首个内联数据包
 * 仍由页面自己渲染。
 *
 * 用途：与「内联首屏」配合时，整页不需要监听端口，也没有同源/端口冲突问题。
 */
class HostTransport {
    constructor(ui, opts) {
        this.ui = ui;
        this.opts = opts || {};
        this.opened = false;
    }
    connect() {
        this.opened = true;
        // 宿主绑定下没有"连接后握手"帧；会话树已随首屏内联，宿主可直接开始交互
    }
    send(data) {
        try {
            if (this.opts.send) this.opts.send(JSON.stringify(data));
            return true;
        } catch (e) {
            console.error('cjxt host transport send failed:', e && e.message);
            return false;
        }
    }
    sendBinary() {
        // 二进制上传需要真正的流式连接；宿主绑定下不支持，明确拒绝而不是静默丢弃
        console.warn('cjxt: binary upload requires a WebSocket transport');
        return false;
    }
    get isOpen() { return this.opened; }
}

class CangjieUI {
    constructor(container, sessionId, initialTree, transport) {
        this.container = container;
        this.sessionId = sessionId;
        this.tree = initialTree;
        // 传输层：默认 WebSocket；宿主绑定/测试可注入（见 HostTransport）。
        // 构造参数优先，其次 window.__CJXT_TRANSPORT__（宿主在页面脚本前注入）。
        this.transport = transport
            || (typeof window !== 'undefined' ? window.__CJXT_TRANSPORT__ : null)
            || new WebSocketTransport(this);
        // WS 二进制帧上传：串行队列 + 块级 ack 背压（每块等 upload_progress 再发下一块）
        this._uploadSeq = 0;
        this._uploadQueue = [];
        this._uploading = false;
        this._uploadWaiters = new Map();
        this.init();
        window.CJXT = { registerComponent: this.registerComponent.bind(this) };
        // 组件 JS（tooltip/popover）先于构造执行，注册函数已挂入待注册队列 → 统一 flush
        (window.__CJXT_PENDING__ || []).forEach((fn) => { try { fn(); } catch (e) { console.error('cjxt register:', e); } });
    }
    init() {
        if (this.tree) this.renderTree(this.tree, this.container);
        this.attachClickDelegate();
        this.attachKeyDelegate();
        this.attachHistoryHandler();
        this.transport.connect();
    }
    /** 宿主把一条页面入站消息交给前端（HostTransport 场景） */
    receive(text) {
        let msg;
        try {
            msg = typeof text === 'string' ? JSON.parse(text) : text;
        } catch (e) {
            console.error('cjxt receive: bad message', e && e.message);
            return;
        }
        if (msg.kind === 'upload_progress' || msg.kind === 'upload_error') {
            this.handleUploadMsg(msg);
            return;
        }
        // 单帧处理失败不能中断调用方（宿主一次可能连续注入多帧）：
        // 不隔离的话，一帧抛异常会让后续帧全部丢弃，且异常穿透到宿主桥，
        // 表现为"点了没反应"却没有任何可观察的错误。
        try {
            this.handleMsg(msg);
        } catch (e) {
            console.error('cjxt receive: frame failed', msg && msg.kind, e && e.message);
        }
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
            // label 内隐藏 input（checkbox/radio）的点击是 label 点击的“合成回放”：
            // 浏览器默认行为会让 label 关联的 input 再派发一次 click，冒泡后会被本委托
            // 再次分发（closest 找到同一 label）→ 同一动作执行两次（如 Table 选择被 toggle 两次）。
            // 隐藏 input 不可见不可直接点击，直接跳过由 label 主导的派发。
            const t = e.target;
            if (t && t.tagName === 'INPUT' && (t.type === 'checkbox' || t.type === 'radio') && t.closest('label')) return;
            const el = e.target.closest('[data-action-click]');
            if (!el) return;
            const name = el.getAttribute('data-action-click');
            this.send({ type: 'action', name, params: this.collectParams(el), sessionId: this.sessionId });
        });
    }
    // ============ 上传（WS 二进制帧流式） ============
    handleUploadMsg(msg) {
        const w = this._uploadWaiters.get(msg.id);
        if (!w) return;
        this._uploadWaiters.delete(msg.id);
        if (msg.kind === 'upload_error') w.rej(new Error(msg.message || 'upload failed'));
        else w.res(msg.received);
    }
    pumpUpload() {
        if (this._uploading) return;
        const item = this._uploadQueue.shift();
        if (!item) return;
        this._uploading = true;
        this.uploadOne(item)
            .catch(err => console.error('cjxt upload failed:', err && err.message))
            .finally(() => {
                this._uploading = false;
                this.pumpUpload();
            });
    }
    async uploadOne(item) {
        const id = String(++this._uploadSeq);
        const CHUNK = 256 * 1024;
        this.send({ type: 'upload_begin', id, name: item.file.name, size: item.file.size, action: item.action });
        let off = 0;
        while (off < item.file.size) {
            const buf = await item.file.slice(off, off + CHUNK).arrayBuffer();
            const ack = new Promise((res, rej) => this._uploadWaiters.set(id, { res, rej }));
            if (!this.transport.sendBinary(buf)) {
                this._uploadWaiters.delete(id);
                throw new Error('binary upload requires a WebSocket transport');
            }
            await ack;
            off += buf.byteLength;
        }
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
        return this.transport.send(data);
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
        this.tabsBarAll();
        if (msg.path) {
            this.pushHistory(msg.path);
        }
        this.send({ type: 'ack', event: 'mount', sessionId: this.sessionId });
    }

    // 写地址栏。**必须容忍失败**：`file://` 页面的 origin 是 `null`，
    // pushState 会抛 SecurityError（浏览器不允许改这类文档的 URL）。
    // 此前未捕获，异常冒泡出 receive → 中断同批次后续帧，表现为
    // "点击导航没反应"（其实已渲染，只是异常把调用链打断了）。
    pushHistory(path) {
        try {
            history.pushState(null, '', path);
        } catch (e) {
            // 无地址栏可写（file:// 等）：功能不受影响，静默降级
        }
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
        if (el.hasAttribute('data-slider')) this.attachSlider(el);
        if (el.hasAttribute('data-splitter-drag')) this.attachSplitter(el);
        if (el.hasAttribute('data-scrollbar')) this.attachScrollbar(el);
        if (el.hasAttribute('data-select')) this.attachSelect(el);
        if (el.hasAttribute('data-rate')) this.attachRate(el);
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
        if (el.hasAttribute('data-slider')) this.attachSlider(el);
        if (el.hasAttribute('data-splitter-drag')) this.attachSplitter(el);
        if (el.hasAttribute('data-scrollbar')) this.attachScrollbar(el);
        if (el.hasAttribute('data-select')) this.attachSelect(el);
        if (el.hasAttribute('data-rate')) this.attachRate(el);
        if (el.hasAttribute('data-auto-dismiss')) this.attachAutoDismiss(el);
        if (el.hasAttribute('data-upload-trigger') || el.hasAttribute('data-upload-input')) this.attachUpload(el);
        return el;
    }

    // 设置元素属性（新建/reconcile 通用；bound input 的 value 更新走守卫，避免打断输入）
    applyAttrs(el, node) {
        const attrs = node.attrs || {};
        // value 是特殊属性：服务端**不再给出** value 时表示"清空"（如 DatePicker 的 × 清空），
        // 必须把 el.value 也清掉 —— 之前这里 `continue` 跳过了移除，
        // 导致「服务端已清空但界面仍显示旧值」（点 × 值不去掉的根因）。
        // 但仍要尊重输入态守卫：正在输入(composing)或有未提交绑定(dirty)时不覆盖。
        const valueMissing = !('value' in attrs);
        if (valueMissing) {
            const composing = el.dataset.composing === '1';
            const dirty = el.dataset.bindDirty === '1';
            // 只对表单控件生效，避免误改普通元素的同名属性
            const isFormField = el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT';
            if (isFormField && !composing && !dirty && el.value !== '') el.value = '';
        }
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
        // innerhtml 节点：内容由 innerHTML 整体管理（children 恒为空）。
        // 若继续 reconcileChildren(el, [])，会把 applyAttrs 刚渲染出的内容子节点
        // 当作"多余 existing"全部删除（切走再切回 Markdown demo → 内容空白）。
        const hasInner = Object.keys(node.attrs || {}).some(k => k.toLowerCase() === 'innerhtml');
        if (!hasInner) this.reconcileChildren(el, node.children || []);
        if (el.hasAttribute('data-bind-id') && !el.__cjxtBound) { this.attachBind(el); el.__cjxtBound = true; }
        if (el.hasAttribute('data-vscroll') && !el.__cjxtVScroll) { this.attachVScroll(el); el.__cjxtVScroll = true; }
        if (el.hasAttribute('data-slider') && !el.__cjxtSlider) { this.attachSlider(el); el.__cjxtSlider = true; }
        if (el.hasAttribute('data-splitter-drag') && !el.__cjxtSplitter) { this.attachSplitter(el); el.__cjxtSplitter = true; }
        if (el.hasAttribute('data-scrollbar') && !el.__cjxtScrollbar) { this.attachScrollbar(el); el.__cjxtScrollbar = true; }
        if (el.hasAttribute('data-select') && !el.__cjxtSelect) { this.attachSelect(el); el.__cjxtSelect = true; }
        if (el.hasAttribute('data-rate') && !el.__cjxtRate) { this.attachRate(el); el.__cjxtRate = true; }
        if (el.hasAttribute('data-auto-dismiss') && !el.__cjxtAutoDismiss) { this.attachAutoDismiss(el); el.__cjxtAutoDismiss = true; }
        if ((el.hasAttribute('data-upload-trigger') || el.hasAttribute('data-upload-input')) && !el.__cjxtUpload) { this.attachUpload(el); el.__cjxtUpload = true; }
    }

    // 上传：触发区点击 → 打开 file input；file change → WS 二进制帧流式上传 →
    // server 收满后按 data-action-uploaded（稳定 handler id）dispatch action（服务端 handler 加文件到列表）
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
                const action = el.getAttribute('data-action-uploaded');
                if (!action) return;
                // 入队逐文件上传（服务端单流限制：binary 帧无元数据，串行最稳）
                this._uploadQueue.push({ file, action });
                this.pumpUpload();
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

    // 评分：点击星左半（可半星）→ 手动派发 action（params.half=1），避免委托重复触发
    attachRate(el) {
        if (el.__cjxtRate) return;
        el.__cjxtRate = true;
        el.addEventListener('click', (e) => {
            const item = e.target.closest('.el-rate__item');
            if (!item) return;
            // action 挂在 item 自身（onClick 在 item 上），querySelector 只搜后代——必须取属性
            const actionName = item.getAttribute('data-action-click') || (item.querySelector('[data-action-click]') || {}).getAttribute?.('data-action-click');
            if (!actionName) return;
            // capture 阶段拦截：阻止冒泡到 container 的委托（委托会再派发一次）
            e.stopPropagation();
            // 以星图标自身 rect 判左右半（item 可能宽于星，导致左半判定偏移）
            const iconEl = e.target.closest('.el-rate__icon') || item;
            const rect = iconEl.getBoundingClientRect();
            const half = (e.clientX !== 0 && e.clientX >= rect.left && e.clientX < rect.left + rect.width / 2);
            this.send({ type: 'action', name: actionName, params: half ? { half: '1' } : {}, sessionId: this.sessionId });
        }, true);
    }

    // 下拉选择（EP DOM 结构）：点击外部关闭 + 选项 hover 高亮类 + 搜索输入框键盘 preventDefault
    attachSelect(el) {
        const self = this;
        // 1) 点击外部 → 按 data-select-close 派发关闭 action（服务端关面板；面板打开时 wrapper 带 is-focused）
        document.addEventListener('click', (e) => {
            if (el.contains(e.target)) return;
            const wrapper = el.querySelector('.el-select__wrapper');
            if (!wrapper || !wrapper.classList.contains('is-focused')) return;
            const closer = el.getAttribute('data-select-close');
            if (closer) self.send({ type: 'action', name: closer, params: {}, sessionId: self.sessionId });
        });
        // 2) 选项 hover：客户端切换 is-hovering 类（服务端键盘高亮走同一类，patch 会重置为服务端状态）
        const list = el.querySelector('.el-select-dropdown__list');
        if (list) {
            list.addEventListener('mousemove', (e) => {
                const item = e.target.closest('.el-select-dropdown__item');
                list.querySelectorAll('.el-select-dropdown__item.is-hovering').forEach((x) => {
                    if (x !== item) x.classList.remove('is-hovering');
                });
                if (item) item.classList.add('is-hovering');
            });
        }
        // 3) 搜索输入：方向/回车/Esc 交给服务端 KeyEvent 处理，前端 preventDefault（防光标移动/表单提交）
        const input = el.querySelector('.el-select__input');
        if (input && !input.__cjxtSelectInput) {
            input.__cjxtSelectInput = true;
            input.addEventListener('keydown', (e) => {
                if (['ArrowDown', 'ArrowUp', 'Enter', 'Escape'].includes(e.key)) e.preventDefault();
            });
        }
    }
    // 滑块（EP DOM 结构）：pointer 拖动/点击 + 键盘 → 位置/键码换算值 → bind 消息回传（rAF 节流）
    attachSlider(el) {
        const bid = el.getAttribute('data-bind-id');
        if (!bid) return;
        const min = Number(el.getAttribute('data-min') || 0);
        const max = Number(el.getAttribute('data-max') || 100);
        const step = Number(el.getAttribute('data-step') || 1);
        const self = this;
        let dragging = false;
        let raf = null;
        let lastValue = null;

        const wrapper = () => el.querySelector('.el-slider__button-wrapper');
        const valueFromEvent = (e) => {
            const rect = el.getBoundingClientRect();
            if (rect.width <= 0) return null;
            const ratio = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width));
            const raw = min + ratio * (max - min);
            let v = min + Math.round((raw - min) / step) * step;
            if (v < min) v = min;
            if (v > max) v = max;
            return v;
        };
        const sendValue = (v) => {
            if (v === null || v === lastValue) return;
            lastValue = v;
            if (raf) return;
            raf = requestAnimationFrame(() => {
                raf = null;
                self.send({ type: 'bind', name: bid, value: String(lastValue) });
            });
        };
        const setDragging = (on) => {
            dragging = on;
            const w = wrapper();
            if (w) w.classList.toggle('dragging', on);
        };
        el.addEventListener('pointerdown', (e) => {
            if (el.classList.contains('is-disabled')) return;
            if (el.setPointerCapture) { try { el.setPointerCapture(e.pointerId); } catch (_) {} }
            setDragging(true);
            sendValue(valueFromEvent(e));
            e.preventDefault();
        });
        el.addEventListener('pointermove', (e) => { if (dragging) sendValue(valueFromEvent(e)); });
        el.addEventListener('pointerup', () => setDragging(false));
        el.addEventListener('pointercancel', () => setDragging(false));
        // 键盘（焦点在 button-wrapper，事件冒泡到 runway）：方向键 ±step、Page ±10step、Home/End 边界
        el.addEventListener('keydown', (e) => {
            if (el.classList.contains('is-disabled')) return;
            const w = wrapper();
            const cur = w ? Number(w.getAttribute('aria-valuenow') || 0) : 0;
            const pg = step * 10;
            let v = cur;
            switch (e.key) {
                case 'ArrowLeft': case 'ArrowDown': v = cur - step; break;
                case 'ArrowRight': case 'ArrowUp': v = cur + step; break;
                case 'PageDown': v = cur - pg; break;
                case 'PageUp': v = cur + pg; break;
                case 'Home': v = min; break;
                case 'End': v = max; break;
                default: return;
            }
            if (v < min) v = min;
            if (v > max) v = max;
            sendValue(v);
            e.preventDefault();
        });
    }
    registerComponent(name, compClass) {
        window.__CJXT_COMPONENTS__ = window.__CJXT_COMPONENTS__ || {};
        window.__CJXT_COMPONENTS__[name] = compClass;
    }
    // 分割面板拖拽（EP splitter DOM）：pointer 拖动 → 按容器比例算面板新尺寸
    //    → bind 消息回传（rAF 节流），服务端写 sizes 信号后重渲染。
    // 与 Slider 同一套模式（data-bind-id + bind 消息），不新增协议消息类型。
    // 只上报「被拖的那一块」的新尺寸，相邻面板由 flex-grow 规则自然吸收。
    attachSplitter(el) {
        const bid = el.getAttribute('data-bind-id');
        if (!bid) return;
        const self = this;
        const index = Number(el.getAttribute('data-splitter-index') || 0);
        const horizontal = el.getAttribute('data-splitter-axis') !== 'vertical';
        const minPx = parseFloat(el.getAttribute('data-splitter-min') || '0') || 0;
        const maxAttr = el.getAttribute('data-splitter-max') || '';
        const maxPx = maxAttr ? (parseFloat(maxAttr) || Infinity) : Infinity;
        const canResize = !el.classList.contains('is-disabled');
        if (!canResize) return;

        // 容器与目标面板：dragger 在 .el-splitter-bar 里，bar 与目标 panel 同级
        const bar = el.closest('.el-splitter-bar');
        const root = el.closest('.el-splitter');
        if (!bar || !root) return;
        const targetPanel = root.querySelector('[data-splitter-panel="' + index + '"]');
        if (!targetPanel) return;

        let dragging = false;
        let raf = null;
        let lastSize = null;
        let startPos = 0;
        let startSize = 0;

        const measure = () => {
            const rr = root.getBoundingClientRect();
            const pr = targetPanel.getBoundingClientRect();
            return {
                container: horizontal ? rr.width : rr.height,
                current: horizontal ? pr.width : pr.height,
                origin: horizontal ? rr.left : rr.top
            };
        };

        const emit = (px) => {
            const rounded = Math.round(px);
            if (rounded === lastSize) return;
            lastSize = rounded;
            if (raf) return;
            raf = requestAnimationFrame(() => {
                raf = null;
                // 服务端 normalizePanelSize 接受 "313px"，按 px 落 flex-basis
                self.send({ type: 'bind', name: bid, value: lastSize + 'px' });
            });
        };

        const clampPx = (px, container) => {
            let v = px;
            if (v < minPx) v = minPx;
            if (v > maxPx) v = maxPx;
            // 至少留 20px 给相邻面板，避免拖成 0 宽后无法再拖回来
            const room = Math.max(20, container - 20);
            if (v > room) v = room;
            return v;
        };

        el.addEventListener('pointerdown', (e) => {
            if (el.setPointerCapture) { try { el.setPointerCapture(e.pointerId); } catch (_) {} }
            const m = measure();
            dragging = true;
            startPos = horizontal ? e.clientX : e.clientY;
            startSize = m.current;
            el.classList.add('is-dragging');
            e.preventDefault();
        });

        el.addEventListener('pointermove', (e) => {
            if (!dragging) return;
            const m = measure();
            const now = horizontal ? e.clientX : e.clientY;
            emit(clampPx(startSize + (now - startPos), m.container));
        });

        const stop = () => {
            if (!dragging) return;
            dragging = false;
            el.classList.remove('is-dragging');
        };
        el.addEventListener('pointerup', stop);
        el.addEventListener('pointercancel', stop);

        // 键盘可达：方向键 ±16px，Home/End 到上下限
        el.setAttribute('tabindex', el.getAttribute('tabindex') || '0');
        el.addEventListener('keydown', (e) => {
            const m = measure();
            let px = m.current;
            if (horizontal) {
                if (e.key === 'ArrowLeft') px -= 16;
                else if (e.key === 'ArrowRight') px += 16;
                else if (e.key === 'Home') px = minPx;
                else if (e.key === 'End') px = Math.min(maxPx, m.container - 20);
                else return;
            } else {
                if (e.key === 'ArrowUp') px -= 16;
                else if (e.key === 'ArrowDown') px += 16;
                else if (e.key === 'Home') px = minPx;
                else if (e.key === 'End') px = Math.min(maxPx, m.container - 20);
                else return;
            }
            emit(clampPx(px, m.container));
            e.preventDefault();
        });
    }

    // 自定义滚动条（EP scrollbar）：thumb 尺寸/位移按 EP bar.vue 的公式算。
    // 服务端只出结构骨架（尺寸留空、display:none），几何完全由这里写入内联 style ——
    // 因为 scrollHeight/clientHeight 只有浏览器知道。
    // 与 Slider/Splitter 不同，这里**不发送任何消息**：滚动纯客户端状态，服务端不需要知道。
    attachScrollbar(el) {
        const wrap = el.querySelector(':scope > .el-scrollbar__wrap');
        if (!wrap) return;
        const barY = el.querySelector(':scope > .el-scrollbar__bar.is-vertical');
        const barX = el.querySelector(':scope > .el-scrollbar__bar.is-horizontal');
        const thumbY = barY ? barY.querySelector('.el-scrollbar__thumb') : null;
        const thumbX = barX ? barX.querySelector('.el-scrollbar__thumb') : null;
        const GAP = 4;              // EP util.ts：top 2 + bottom 2 of bar instance
        const MIN_SIZE = 20;        // EP scrollbarProps.minSize 默认值
        if (!thumbY && !thumbX) return;

        // EP update()：original = offset² / scroll，size = max(original, minSize)
        const thumbSize = (offset, scroll) => {
            if (scroll <= offset) return 0;   // 不需要滚动
            const original = (offset * offset) / scroll;
            return Math.max(original, MIN_SIZE);
        };

        const sync = () => {
            const offY = wrap.clientHeight - GAP;
            const offX = wrap.clientWidth - GAP;

            if (thumbY && barY) {
                const sizeY = thumbSize(offY, wrap.scrollHeight);
                if (sizeY <= 0 || sizeY + GAP >= offY) {
                    barY.style.display = 'none';
                } else {
                    barY.style.display = '';
                    thumbY.style.display = '';
                    thumbY.style.height = sizeY + 'px';
                    // 可移动范围 = bar 高度 - thumb 高度；按 scrollTop 比例平移
                    const range = barY.clientHeight - sizeY;
                    const ratio = wrap.scrollTop / Math.max(1, wrap.scrollHeight - wrap.clientHeight);
                    thumbY.style.transform = 'translateY(' + (range * ratio) + 'px)';
                }
            }
            if (thumbX && barX) {
                const sizeX = thumbSize(offX, wrap.scrollWidth);
                if (sizeX <= 0 || sizeX + GAP >= offX) {
                    barX.style.display = 'none';
                } else {
                    barX.style.display = '';
                    thumbX.style.display = '';
                    thumbX.style.width = sizeX + 'px';
                    const range = barX.clientWidth - sizeX;
                    const ratio = wrap.scrollLeft / Math.max(1, wrap.scrollWidth - wrap.clientWidth);
                    thumbX.style.transform = 'translateX(' + (range * ratio) + 'px)';
                }
            }
        };

        // 拖动 thumb / 点击轨道（EP bar.vue 的 clickTrackHandler + clickThumbHandler）。
        // 注意：不拖动时 thumb 只由 sync() 跟随 —— 拖拽期间要**反过来**由指针位置驱动 scrollLeft/Top，
        // 否则 scroll 事件又会写 transform，两者互相打架会「拖不动」。
        const bindDrag = (bar, thumb, vertical) => {
            if (!bar || !thumb) return;
            let dragging = false;
            let startPointer = 0;
            let startScroll = 0;

            const onMove = (e) => {
                if (!dragging) return;
                // thumb 移动 1px 对应内容滚动 (contentSize - clientSize) / (barSize - thumbSize) px
                const offset = vertical ? wrap.clientHeight - GAP : wrap.clientWidth - GAP;
                const range = vertical ? bar.clientHeight - thumb.getBoundingClientRect().height
                                       : bar.clientWidth - thumb.getBoundingClientRect().width;
                if (range <= 0) return;
                const contentRange = vertical ? (wrap.scrollHeight - wrap.clientHeight)
                                              : (wrap.scrollWidth - wrap.clientWidth);
                const delta = (vertical ? e.clientY : e.clientX) - startPointer;
                const next = startScroll + delta * (contentRange / range);
                if (vertical) { wrap.scrollTop = next; } else { wrap.scrollLeft = next; }
                e.preventDefault();
            };
            const onUp = () => {
                dragging = false;
                document.removeEventListener('pointermove', onMove);
                document.removeEventListener('pointerup', onUp);
                document.removeEventListener('pointercancel', onUp);
            };

            thumb.addEventListener('pointerdown', (e) => {
                dragging = true;
                startPointer = vertical ? e.clientY : e.clientX;
                startScroll = vertical ? wrap.scrollTop : wrap.scrollLeft;
                // 监听挂 document：手指/指针移出 thumb 也要继续跟
                document.addEventListener('pointermove', onMove);
                document.addEventListener('pointerup', onUp);
                document.addEventListener('pointercancel', onUp);
                e.preventDefault();
                e.stopPropagation();
            });

            // 点击轨道空白处：朝点击位置翻页，与 EP clickTrackHandler 同思路
            bar.addEventListener('pointerdown', (e) => {
                if (e.target === thumb) return;
                const rect = bar.getBoundingClientRect();
                const contentRange = vertical ? (wrap.scrollHeight - wrap.clientHeight)
                                              : (wrap.scrollWidth - wrap.clientWidth);
                const ratio = vertical
                    ? (e.clientY - rect.top) / rect.height
                    : (e.clientX - rect.left) / rect.width;
                if (vertical) { wrap.scrollTop = contentRange * ratio; }
                else { wrap.scrollLeft = contentRange * ratio; }
                e.preventDefault();
            });
        };
        bindDrag(barY, thumbY, true);
        bindDrag(barX, thumbX, false);

        // 滚动：只更新 thumb，不碰内容
        wrap.addEventListener('scroll', sync, { passive: true });
        // 尺寸变化（容器/内容）：ResizeObserver 观察 wrap 与 view
        const view = wrap.querySelector(':scope > .el-scrollbar__view') || wrap;
        if (typeof ResizeObserver !== 'undefined') {
            const ro = new ResizeObserver(() => sync());
            ro.observe(wrap);
            ro.observe(view);
            el.__cjxtScrollbarRO = ro;
        }
        // 首帧：DOM 可能还没布局完成，下一帧再算一次
        sync();
        if (typeof requestAnimationFrame !== 'undefined') requestAnimationFrame(sync);
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
        // 自动滚动到选中项（data-scroll-active）：打开/更新后把 .is-active 项滚到容器中线
        this.scrollActiveAll();
        // Tabs 滑动 active-bar 定位
        this.tabsBarAll();
    }
    autoScrollAll() {
        document.querySelectorAll('[data-auto-scroll]').forEach((el) => {
            const dist = el.scrollHeight - el.scrollTop - el.clientHeight;
            if (dist < 80) el.scrollTop = el.scrollHeight;
        });
    }
    scrollActiveAll() {
        document.querySelectorAll('[data-scroll-active]').forEach((el) => {
            const act = el.querySelector('.is-active');
            if (!act) return;
            const r = act.getBoundingClientRect();
            const cr = el.getBoundingClientRect();
            el.scrollTop += (r.top + r.height / 2) - (cr.top + cr.height / 2);
        });
    }
    // Tabs 滑动 active-bar（data-tabs-bar）：把 bar 定位到 .el-tabs__item.is-active（EP 测量语义，rect 差值安全）
    tabsBarAll() {
        document.querySelectorAll('[data-tabs-bar]').forEach((bar) => {
            const nav = bar.parentElement;
            if (!nav) return;
            const active = nav.querySelector('.el-tabs__item.is-active');
            if (!active) return;
            const vert = bar.classList.contains('is-left') || bar.classList.contains('is-right');
            const p = bar.offsetParent;
            const pr = p ? p.getBoundingClientRect() : { left: 0, top: 0 };
            const ar = active.getBoundingClientRect();
            if (vert) {
                bar.style.height = ar.height + 'px';
                bar.style.transform = 'translateY(' + (ar.top - pr.top) + 'px)';
            } else {
                bar.style.width = ar.width + 'px';
                bar.style.transform = 'translateX(' + (ar.left - pr.left) + 'px)';
            }
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
