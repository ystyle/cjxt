(function() {
    function register() {
        if (!window.CJXT) return false;
        window.CJXT.registerComponent('Popconfirm', class {
        create(props, container) {
            container.style.cssText = 'position:relative;display:inline-block;';
            const trigger = document.createElement('span');
            trigger.textContent = props.triggerText || '点击';
            trigger.className = 'el-popconfirm-trigger';
            trigger.style.cssText = 'cursor:pointer;color:#409eff;user-select:none;';
            container.appendChild(trigger);

            const popper = document.createElement('div');
            popper.className = 'el-popover el-popper';
            const w = props.width ? props.width + 'px' : '150px';
            popper.style.cssText = 'display:none;position:absolute;z-index:2000;background:#fff;border:1px solid #e4e7ed;border-radius:4px;padding:12px;box-shadow:0 2px 12px rgba(0,0,0,0.12);min-width:' + w + ';box-sizing:border-box;';

            // EP 结构：.el-popconfirm > __main(icon+title) + __action(取消/确定)
            const box = document.createElement('div');
            box.className = 'el-popconfirm';
            box.tabIndex = -1;
            const main = document.createElement('div');
            main.className = 'el-popconfirm__main';
            const icon = document.createElement('i');
            icon.className = 'el-icon el-popconfirm__icon';
            icon.style.cssText = 'color:#f90;margin-right:5px;font-size:14px;';
            icon.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" style="width:14px;height:14px"><path fill="currentColor" d="M512 64a448 448 0 1 1 0 896 448 448 0 0 1 0-896m23.7 191.5q-77.9 0-123.2 44.3c-31 29.6-45.7 70.4-45.7 122.5H447c0-29.5 5.7-52.8 17.6-69 13.4-19.7 35.2-28.8 66.2-28.8q36.2-.2 56.3 19.7a77 77 0 0 1 19.7 54.9 78 78 0 0 1-19 50l-8.4 9.8c-45.8 40.9-73.2 70.4-82.4 89.5-9.8 19-14 42.2-14 69v9.8h80.9v-9.9c0-16.9 3.5-31.6 10.6-45.7a109 109 0 0 1 28.1-35.2c33.8-29.6 54.2-48.6 60.6-55.6 16.9-22.6 26-51.4 26-86.6q0-64.4-42.2-101.4c-28.2-25.3-65.5-37.3-111.3-37.3m-12.6 406.2a54 54 0 0 0-38.7 14.8 49 49 0 0 0-15.5 38c0 15.5 4.9 28.2 15.5 38A55 55 0 0 0 523 768c15.5 0 28.1-5 38.7-14.8a52 52 0 0 0 16.2-38.7 52 52 0 0 0-15.5-38 56 56 0 0 0-39.4-14.8"/></svg>';
            main.appendChild(icon);
            main.appendChild(document.createTextNode(props.title || ''));
            const action = document.createElement('div');
            action.className = 'el-popconfirm__action';
            const mkBtn = (text, cls, ev) => {
                const b = document.createElement('button');
                b.type = 'button';
                b.className = cls;
                b.appendChild(document.createElement('span'));
                b.lastChild.textContent = text;
                b.addEventListener('click', (e) => {
                    e.stopPropagation();
                    const name = container.getAttribute('data-action-' + ev);
                    if (name && window.ui) {
                        window.ui.send({ type: 'action', name, params: {}, sessionId: window.ui.sessionId });
                    }
                    hide();
                });
                return b;
            };
            action.appendChild(mkBtn(props.cancelButtonText || '取消', 'el-button el-button--small is-text', 'cancel'));
            action.appendChild(mkBtn(props.confirmButtonText || '确定', 'el-button el-button--small el-button--primary', 'confirm'));
            box.appendChild(main);
            box.appendChild(action);
            popper.appendChild(box);
            document.body.appendChild(popper);

            this._trigger = trigger;
            this._popper = popper;
            this._container = container;
            this._placement = props.placement || 'bottom';
            this._cleanup = null;

            const show = () => {
                if (props.disabled) return;
                popper.style.display = 'block';
                if (this._cleanup) this._cleanup();
                this._cleanup = FloatingUIDOM.autoUpdate(trigger, popper, () => {
                    FloatingUIDOM.computePosition(trigger, popper, {
                        placement: this._placement,
                        middleware: [FloatingUIDOM.offset(8), FloatingUIDOM.shift({padding: 5})]
                    }).then(({x, y}) => {
                        Object.assign(popper.style, {left: x + 'px', top: y + 'px'});
                    });
                });
            };

            const hide = () => {
                popper.style.display = 'none';
                if (this._cleanup) { this._cleanup(); this._cleanup = null; }
            };

            const triggerType = props.trigger || 'click';
            if (triggerType === 'click') {
                trigger.addEventListener('click', (e) => {
                    e.stopPropagation();
                    document.querySelectorAll('.el-popover').forEach(p => { if (p !== popper) p.style.display = 'none'; });
                    const vis = popper.style.display === 'block';
                    if (vis) hide(); else show();
                });
                this._docClick = (e) => {
                    if (!container.contains(e.target) && !popper.contains(e.target)) hide();
                };
                document.addEventListener('click', this._docClick);
            }
            if (triggerType === 'hover') {
                trigger.addEventListener('mouseenter', show);
                trigger.addEventListener('mouseleave', hide);
                popper.addEventListener('mouseleave', hide);
            }

            return container;
        }
        update(props) {}
        destroy(el) {
            if (this._cleanup) { this._cleanup(); this._cleanup = null; }
            if (this._docClick) document.removeEventListener('click', this._docClick);
            if (this._popper) this._popper.remove();
        }
    });
        return true;
    }
    // 页面 script 顺序：组件 JS 先于 new CangjieUI() 执行 → 延迟注册（同 tooltip.js）
    if (!register()) {
        window.__CJXT_PENDING__ = window.__CJXT_PENDING__ || [];
        window.__CJXT_PENDING__.push(register);
    }
})();
