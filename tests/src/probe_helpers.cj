package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// 渲染辅助 + 按元素派发事件。
//
// 为什么不能"把 handlerMap 里的 handler 全跑一遍"：前端是**按被点击元素自身的 action 派发**的
// （cangjie-ui.js attachClickDelegate 用 `e.target.closest('[data-action-click]')`，
// bind 用元素自身的 data-bind-id）。全跑会同时点中每个标签的关闭按钮和各处键盘动作，
// 测出来的不是任何真实交互。
//
// renderJson 产出的 JSON 里，每个元素都有 `"actions":{...}`，值就是稳定化后的 handler id
// （renderctx.stabilizeVNodeHandlers：`h:<path>:<ev>` / `b:<path>:bind`）。
// 因此可以：定位某个元素的 actions → 取 id → 从 handlerMap 取到 handler → 只调这一个。
// 渲染成 JSON 并收集 handler 表（handlerMap 的 key 与 JSON 里的 action id 一致）
func probeRender(node: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(node, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

// 在 JSON 里定位**第一个**含 marker 的元素，返回其 ev 对应的 handler id。
//
// 两类事件的落点不同（对齐 renderctx.stabilizeVNodeHandlers）：
//   - bind → `attrs.data-bind-id`（值形如 `b:<path>:bind`），**不在** actions 里；
//   - click/keydown/… → `actions` 对象（值形如 `h:<path>:<ev>`）。
// 找不到返回空串。
func probeActionId(json: String, marker: String, ev: String): String {
    let at = match (json.indexOf(marker)) {
        case Some(i) => i
        case None => return ""
    }
    if (ev == "bind") {
        return probeAttrValue(json, at, "\"data-bind-id\":\"")
    }
    let actAt = match (json.indexOf("\"actions\":", at)) {
        case Some(i) => i
        case None => return ""
    }
    probeAttrValue(json, actAt, "\"${ev}\":\"")
}

// 从 from 之后找 `keyValue`（形如 "\"actions\":\"" 或 "\"data-bind-id\":\""）并取出到下一个引号为止的值
func probeAttrValue(json: String, from: Int64, keyValue: String): String {
    let keyAt = match (json.indexOf(keyValue, from)) {
        case Some(i) => i
        case None => return ""
    }
    let start = keyAt + keyValue.size
    let endAt = match (json.indexOf("\"", start)) {
        case Some(i) => i
        case None => return ""
    }
    json[start..endAt]
}

// 按元素派发一个事件：定位 marker 元素的 ev handler 并调用。返回是否真的找到了 handler。
func probeFire(json: String, handlers: HashMap<String, ActionHandler>, marker: String, ev: String, ctx: ActionContext): Bool {
    let id = probeActionId(json, marker, ev)
    if (id == "") { return false }
    match (handlers.get(id)) {
        case Some(h) =>
            let _ = h(ctx)
            true
        case None => false
    }
}

// 在 JSON 里数「以 prefix 开头且紧随其后不是 '-'」的类名出现次数——
// 用来区分 `el-tag` 与 `el-tag--info` 这类前缀重合的类名。
func probeCountClass(json: String, cls: String): Int64 {
    var count = 0
    var from = 0
    var go = true
    let pat = "\"class\":\"${cls}"
    while (go) {
        match (json.indexOf(pat, from)) {
            case Some(i) =>
                let after = i + pat.size
                // 该位置之后必须是类名结束（引号）或类名分隔（空格），否则是同前缀的长类名
                if (after >= json.size || json[after..after + 1] == "\"" || json[after..after + 1] == " ") {
                    count += 1
                }
                from = after
            case None => go = false
        }
    }
    count
}

func probeCtx(sid: String): ActionContext {
    ActionContext(sid, HashMap<String, String>(), HashMap<String, String>(), Router(sid, { _ => () }))
}

func probeCtxValue(sid: String, value: String): ActionContext {
    let p = HashMap<String, String>()
    p["value"] = value
    ActionContext(sid, HashMap<String, String>(), p, Router(sid, { _ => () }))
}

func probeCtxKey(sid: String, key: String, value: String): ActionContext {
    let p = HashMap<String, String>()
    p["key"] = key
    p["code"] = key
    p["keyCode"] = "0"
    p["value"] = value
    ActionContext(sid, HashMap<String, String>(), p, Router(sid, { _ => () }), keyEvent: parseKeyEvent(p))
}

// ArrayList<String> 是否含某值（避免依赖 ArrayList.contains 的版本差异）
func listHas(list: ArrayList<String>, v: String): Bool {
    for (x in list) { if (x == v) { return true } }
    false
}
