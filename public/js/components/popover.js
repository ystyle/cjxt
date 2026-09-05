(function() {
    function register() {
        if (!window.CJXT) return false;
        window.CJXT.registerComponent('Popover', class {
        create(props, container) {
            container.style.cssText = 'position:relative;display:inline-block;';
            const trigger = document.createElement('span');
            trigger.textContent = props.triggerText || '点击';
            trigger.className = 'el-popover-trigger';
            trigger.style.cssText = 'cursor:pointer;color:#409eff;';
            container.appendChild(trigger);

            const popper = document.createElement('div');
            popper.className = 'el-popover el-popper';
            const w = props.width ? props.width + 'px' : '150px';
            popper.style.cssText = 'display:none;min-width:' + w + ';';
            if (props.title) {
                const title = document.createElement('div');
                title.className = 'el-popover__title';
                title.textContent = props.title;
                popper.appendChild(title);
            }
            if (props.content) {
                const body = document.createElement('div');
                body.textContent = props.content;
                popper.appendChild(body);
            }
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
                    }).then(({x, y, placement}) => {
                        popper.setAttribute('data-popper-placement', placement);
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
                popper.addEventListener('mouseenter', () => {});
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