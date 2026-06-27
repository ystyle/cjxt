(function() {
    window.CJXT = window.CJXT || {};
    window.CJXT.registerComponent('Tooltip', class {
        create(props, container) {
            const trigger = document.createElement('span');
            trigger.textContent = props.triggerText || '?';
            trigger.className = 'el-tooltip-trigger';
            trigger.style.cssText = 'cursor:pointer;color:#409eff;border-bottom:1px dashed #409eff;';
            const tip = document.createElement('div');
            tip.className = 'el-tooltip__popper';
            tip.textContent = props.content || '';
            tip.style.cssText = 'display:none;position:absolute;background:#303133;color:#fff;padding:8px 12px;border-radius:4px;font-size:12px;z-index:2000;white-space:nowrap;';
            container.style.cssText = 'position:relative;display:inline-block;';
            container.appendChild(trigger);
            container.appendChild(tip);
            this._trigger = trigger;
            this._tip = tip;
            this._mouseenter = () => { tip.style.display = 'block'; };
            this._mouseleave = () => { tip.style.display = 'none'; };
            trigger.addEventListener('mouseenter', this._mouseenter);
            trigger.addEventListener('mouseleave', this._mouseleave);
            return container;
        }
        update(props) {}
        destroy(el) {
            if (this._trigger && this._mouseenter) {
                this._trigger.removeEventListener('mouseenter', this._mouseenter);
                this._trigger.removeEventListener('mouseleave', this._mouseleave);
            }
        }
    });
})();
