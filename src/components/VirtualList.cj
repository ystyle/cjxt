package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}
import std.convert.*

// ============ VirtualList 虚拟滚动列表（服务端算可视窗口，客户端上报滚动） ============
//
// 原理：滚动位置是客户端状态 → 容器 div 通过 VNode.bind(scrollTopSignal) 注册稳定
// bind id + data-vscroll 标记 → 客户端挂 rAF 节流 scroll 监听，滚动时发 bind 消息
// （value=scrollTop）→ 服务端 dispatchBind 写入 scrollTopSignal → ReRender →
// computeVirtualWindow 只渲染可视窗口行 + 顶部/底部占位（保持总滚动高度）。
// 配合 keyed reconciliation：滚动只 patch 窗口行的变化，性能好。

public class VirtualList<T> <: Component {
    var _items: Signal<ArrayList<T>>
    var _renderItem: (Int64, T) -> IComponent
    var _scrollTop: Signal<Int64>
    var _itemHeight: Int64 = 40
    var _containerHeight: Int64 = 400
    var _buffer: Int64 = 3

    public init(items: Signal<ArrayList<T>>, renderItem: (Int64, T) -> IComponent, scrollTop: Signal<Int64>) {
        this._items = items
        this._renderItem = renderItem
        this._scrollTop = scrollTop
    }

    public func itemHeight(v: Int64): VirtualList<T> { this._itemHeight = v; this }
    public func height(v: Int64): VirtualList<T> { this._containerHeight = v; this }
    public func buffer(v: Int64): VirtualList<T> { this._buffer = v; this }

    public func render(): IComponent {
        let items = this._items.get()
        let total = items.size
        let st = this._scrollTop.get()
        let win = computeVirtualWindow(total, st, this._containerHeight, this._itemHeight, this._buffer)
        let children = ArrayList<IComponent>()
        children.add(this.spacer(win.topSpacer))
        for (i in win.startIndex..win.endIndex) {
            children.add(this._renderItem(i, items[i]))
        }
        children.add(this.spacer(win.bottomSpacer))
        let attrs = HashMap<String, String>()
        attrs["class"] = "el-vlist"
        attrs["data-vscroll"] = "1"
        attrs["style"] = "height:${this._containerHeight}px;overflow-y:auto;position:relative;border:1px solid #e4e7ed;border-radius:6px;background:#fff"
        // 绑定 scrollTop：客户端 scroll 事件通过 bind 消息回传（value=scrollTop 字符串）
        // 用自定义 handler + Int64.parse（通用 VNode.bind 的 JSON readValue 对 Int64 解析字符串会失败）
        let bid = nextBid()
        attrs["data-bind-id"] = bid
        let hmap = HashMap<String, ActionHandler>()
        hmap[bid] = { ctx =>
            let raw = match (ctx.params.get("value")) { case Some(x) => x case None => "" }
            if (raw != "") {
                this._scrollTop.set(Int64.parse(raw, radix: 10))
            }
            PatchResult.ReRender
        }
        VNode("div", children.toArray(), attrs: Some(attrs), handlers: Some(hmap))
    }

    func spacer(px: Int64): IComponent {
        let a = HashMap<String, String>()
        a["style"] = "height:${px}px"
        VNode("div", [], attrs: Some(a))
    }
}
