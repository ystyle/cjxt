(function() {
    function register() {
        if (!window.CJXT) return false;
        window.CJXT.registerComponent('Tooltip', class {
        create(props, container) {
            const trigger = document.createElement('span');
            trigger.textContent = props.triggerText || '?';
            trigger.className = 'el-tooltip-trigger';
            container.style.cssText = 'position:relative;display:inline-block;';
            container.appendChild(trigger);

            const popper = document.createElement('div');
            popper.className = 'el-tooltip__popper is-' + (props.effect || 'dark');
            popper.textContent = props.content || '';
            popper.style.cssText = 'display:none;position:absolute;z-index:2000;padding:8px 12px;border-radius:4px;font-size:12px;line-height:1.4;max-width:350px;word-wrap:break-word;';
            if (props.effect === 'light') {
                popper.style.cssText += 'background:#fff;color:#303133;border:1px solid #e4e7ed;box-shadow:0 2px 12px rgba(0,0,0,0.12);';
            } else {
                popper.style.cssText += 'background:#303133;color:#fff;';
            }
            document.body.appendChild(popper);

            this._trigger = trigger;
            this._popper = popper;
            this._container = container;
            this._placement = props.placement || 'bottom';
            this._cleanup = null;

            let showTimer = null;
            let hideTimer = null;
            const showDelay = props.showAfter || 0;
            const hideDelay = props.hideAfter || 200;

            const show = () => {
                if (hideTimer) { clearTimeout(hideTimer); hideTimer = null; }
                if (props.disabled) return;
                showTimer = setTimeout(() => {
                    popper.style.display = 'block';
                    if (this._cleanup) this._cleanup();
                    this._cleanup = FloatingUIDOM.autoUpdate(trigger, popper, () => {
                        FloatingUIDOM.computePosition(trigger, popper, {
                            placement: this._placement,
                            middleware: [FloatingUIDOM.offset(8), FloatingUIDOM.shift({padding: 5}), FloatingUIDOM.arrow({element: popper.querySelector('.el-popper__arrow')})]
                        }).then(({x, y, middlewareData, placement}) => {
                            Object.assign(popper.style, {left: x + 'px', top: y + 'px'});
                            if (middlewareData.arrow) {
                                const arrow = popper.querySelector('.el-popper__arrow');
                                if (arrow) {
                                    const staticSide = {top: 'bottom', right: 'left', bottom: 'top', left: 'right'}[placement.split('-')[0]];
                                    Object.assign(arrow.style, {
                                        left: middlewareData.arrow.x != null ? middlewareData.arrow.x + 'px' : '',
                                        top: middlewareData.arrow.y != null ? middlewareData.arrow.y + 'px' : '',
                                        right: '',
                                        bottom: '',
                                        [staticSide]: '-4px'
                                    });
                                }
                            }
                        });
                    });
                    showTimer = null;
                }, showDelay);
            };

            const hide = () => {
                if (showTimer) { clearTimeout(showTimer); showTimer = null; }
                hideTimer = setTimeout(() => {
                    popper.style.display = 'none';
                    if (this._cleanup) { this._cleanup(); this._cleanup = null; }
                    hideTimer = null;
                }, hideDelay);
            };

            const triggerType = props.trigger || 'hover';
            if (triggerType === 'hover' || triggerType === 'both') {
                trigger.addEventListener('mouseenter', show);
                trigger.addEventListener('mouseleave', hide);
                popper.addEventListener('mouseenter', () => { if (hideTimer) { clearTimeout(hideTimer); hideTimer = null; } });
                popper.addEventListener('mouseleave', hide);
            }
            if (triggerType === 'click') {
                trigger.addEventListener('click', () => {
                    const vis = popper.style.display === 'block';
                    if (vis) hide(); else show();
                });
                document.addEventListener('click', (e) => {
                    if (!container.contains(e.target) && !popper.contains(e.target)) popper.style.display = 'none';
                });
            }
            if (triggerType === 'focus') {
                trigger.addEventListener('focus', show);
                trigger.addEventListener('blur', hide);
            }

            this._show = show;
            this._hide = hide;

            return container;
        }
        update(props) {}
        destroy(el) {
            if (this._cleanup) { this._cleanup(); this._cleanup = null; }
            if (this._popper) this._popper.remove();
        }
        });
        return true;
    }
    // 页面 script 顺序：组件 JS 先于 new CangjieUI() 执行，此时 window.CJXT 未设置
    // → 挂到待注册队列，构造函数创建 CJXT 后统一 flush
    if (!register()) {
        window.__CJXT_PENDING__ = window.__CJXT_PENDING__ || [];
        window.__CJXT_PENDING__.push(register);
    }
})();
