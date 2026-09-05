package cjxt.components

import cjxt.*
import std.collection.HashMap
import stdx.encoding.json.stream.JsonSerializable

// EP Popconfirm（基于 Tooltip click 触发，popper-class = el-popover）：
//   .el-popover.el-popper
//     .el-popconfirm[tabindex=-1]
//       .el-popconfirm__main       → el-icon.el-popconfirm__icon(QuestionFilled, color #f90) + title 文本
//       .el-popconfirm__action     → button 取消(is-text small) + button 确定(primary small)
// 客户端（popconfirm.js）负责 popper 定位（FloatingUI）、click 外部关闭与 confirm/cancel 派发；
// 服务端通过 ClientComponentNode.on("confirm"/"cancel", h) 注册回调，走标准 action 链路。
public class Popconfirm <: Component {
    var _title: String
    var _triggerText: String
    var _confirmText: String = "确定"
    var _cancelText: String = "取消"
    var _width: Int64 = 150
    var _confirmH: Option<ActionHandler> = None
    var _cancelH: Option<ActionHandler> = None

    public init(title: String, triggerText: String) {
        this._title = title
        this._triggerText = triggerText
    }
    public func confirmButtonText(t: String): Popconfirm { this._confirmText = t; this }
    public func cancelButtonText(t: String): Popconfirm { this._cancelText = t; this }
    public func width(w: Int64): Popconfirm { this._width = w; this }
    public func onConfirm(h: ActionHandler): Popconfirm { this._confirmH = Some(h); this }
    public func onCancel(h: ActionHandler): Popconfirm { this._cancelH = Some(h); this }

    public func render(): IComponent {
        let props = HashMap<String, JsonSerializable>()
        props["title"] = this._title
        props["triggerText"] = this._triggerText
        props["confirmButtonText"] = this._confirmText
        props["cancelButtonText"] = this._cancelText
        props["width"] = this._width
        var node = ClientComponentNode("Popconfirm", props)
        match (this._confirmH) {
            case Some(h) => node = node.on("confirm", h)
            case None => ()
        }
        match (this._cancelH) {
            case Some(h) => node = node.on("cancel", h)
            case None => ()
        }
        node
    }
}
