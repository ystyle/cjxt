(function() {
    window.CJXT = window.CJXT || {};
    window.CJXT.registerComponent('Popover', class {
        create(props, container) {
            container.style.cssText = 'position:relative;display:inline-block;';
            const trigger = document.createElement('span');
            trigger.textContent = props.triggerText || '点击';
            trigger.className = 'el-popover-trigger';
            trigger.style.cssText = 'cursor:pointer;color:#409eff;';
            const popover = document.createElement('div');
            popover.className = 'el-popover';
            popover.style.cssText = 'display:none;position:absolute;z-index:2000;background:#fff;border:1px solid #e4e7ed;border-radius:4px;padding:12px;box-shadow:0 2px 12px rgba(0,0,0,0.12);min-width:200px;';
            if (props.title) {
                const title = document.createElement('div');
                title.textContent = props.title;
                title.style.cssText = 'font-size:14px;font-weight:600;margin-bottom:8px;color:#303133;';
                popover.appendChild(title);
            }
            if (props.content) {
                const body = document.createElement('div');
                body.textContent = props.content;
                body.style.cssText = 'font-size:13px;color:#606266;';
                popover.appendChild(body);
            }
            container.appendChild(trigger);
            container.appendChild(popover);
            this._trigger = trigger;
            this._popover = popover;
            this._container = container;
            this._docClick = (e) => {
                if (!container.contains(e.target)) {
                    popover.style.display = 'none';
                }
            };
            trigger.addEventListener('click', (e) => {
                e.stopPropagation();
                const vis = popover.style.display === 'block';
                document.querySelectorAll('.el-popover').forEach(p => { if (p !== popover) p.style.display = 'none'; });
                popover.style.display = vis ? 'none' : 'block';
            });
            document.addEventListener('click', this._docClick);
            return container;
        }
        update(props) {}
        destroy(el) {
            if (this._docClick) {
                document.removeEventListener('click', this._docClick);
            }
        }
    });
})();
