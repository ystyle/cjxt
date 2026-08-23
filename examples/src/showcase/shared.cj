// 演示站共享基础设施（package examples.showcase）
// 注意：子包不能 import 主包 examples（executable 模式），因此 CSS 模块
// （@importCSS + cls）从主包移到这里，主包各页面通过 import 本包使用。

package examples.showcase

import cjxt.*
import cjxt.macros.*
import cjxt.components.*
import std.collection.{ArrayList, HashMap}

let css = @importCSS("style.css")
public func cls(name: String): String { css.get(name) }

// ============ 统一的演示区块标题组件 ============

/// 演示区块标题：统一 14px / 600 / #303133 / 左对齐（.demo-section-title）
public class SectionTitle <: Component {
    let _text: String
    public init(text: String) { this._text = text }
    public func render(): IComponent {
        div([text(this._text)], attrs: Some(HashMap<String, String>([("class", cls("demo-section-title"))])))
    }
}

/// 统一的演示区块：标题（左对齐）+ 内容（左对齐、撑满）
/// 每个 demo 由若干 demoSection 组成，结构完全一致
public func demoSection(title: String, children: Array<IComponent>): IComponent {
    div([
        SectionTitle(title),
        div(children, attrs: Some(HashMap<String, String>([("class", cls("demo-content"))]))),
    ], attrs: Some(HashMap<String, String>([("class", cls("demo-section"))])))
}

// ============ 属性面板行 ============

func propRow(name: String, typ: String, desc: String): IComponent {
    div([
        div([text(name)], attrs: Some(HashMap<String, String>([("class", cls("showcase-prop-name"))]))),
        div([text(typ)], attrs: Some(HashMap<String, String>([("class", cls("showcase-prop-type"))]))),
        div([text(desc)], attrs: Some(HashMap<String, String>([("class", cls("showcase-prop-desc"))]))),
    ], attrs: Some(HashMap<String, String>([("class", cls("showcase-prop-row"))])))
}

// ============ 共享数据 ============

func initTableData(): ArrayList<HashMap<String, String>> {
    let data = ArrayList<HashMap<String, String>>()
    data.add(HashMap<String, String>([("date", "2016-05-03"), ("name", "Tom"), ("state", "California"), ("city", "Los Angeles"), ("address", "No. 189, Grove St, Los Angeles")]))
    data.add(HashMap<String, String>([("date", "2016-05-02"), ("name", "Jerry"), ("state", "California"), ("city", "San Francisco"), ("address", "742 Evergreen Terrace, San Francisco")]))
    data.add(HashMap<String, String>([("date", "2016-05-04"), ("name", "Alice"), ("state", "New York"), ("city", "New York City"), ("address", "350 Fifth Avenue, New York City, NY 10118")]))
    data.add(HashMap<String, String>([("date", "2016-05-01"), ("name", "Bob"), ("state", "Texas"), ("city", "Austin"), ("address", "1100 Congress Ave, Austin, TX 78701")]))
    data
}

func buildAutoScrollItems(items: ArrayList<String>): Array<IComponent> {
    let list = ArrayList<IComponent>()
    for (item in items) {
        let attrs = HashMap<String, String>()
        attrs["style"] = "padding:8px 12px;margin-bottom:8px;background:#ffffff;border-radius:6px"
        list.add(VNode("div", [text(item)], attrs: Some(attrs)))
    }
    list.toArray()
}

// DOM 事务演示组件：用 this.getPath() 定位自身子树元素
class DomTxWidget <: Component {
    let result: Signal<String>
    public init(result: Signal<String>) { this.result = result }

    public func render(): IComponent {
        let focusH: ActionHandler = { ctx =>
            match (ctx.dom) {
                case Some(d) =>
                    // ref 寻址：服务端把 ref 名解析为树路径，客户端 navigateTo 定位
                    d.command([domFocus("domtx-input"), domSetProperty("domtx-status", "innerText", "已聚焦输入框")])
                case None => ()
            }
            PatchResult.ReRender
        }
        let queryH: ActionHandler = { ctx =>
            match (ctx.dom) {
                case Some(d) =>
                    d.query("domtx-widget", "offsetHeight") { results =>
                        let v = match (results.get("r1")) { case Some(x) => x case None => "?" }
                        this.result.set("高度 ${v}px")
                        PatchResult.ReRender
                    }
                case None => ()
            }
            PatchResult.ReRender
        }
        let seqH: ActionHandler = { ctx =>
            match (ctx.dom) {
                case Some(d) =>
                    let seq = d.seq()
                    let hbox = Box<Int64>(0)
                    seq.queryInt64("domtx-widget", "offsetHeight") { h => hbox.value = h }
                    seq.thenInt64("domtx-widget", "offsetWidth") { w =>
                        this.result.set("高+宽=${hbox.value + w}")
                        PatchResult.ReRender
                    }
                case None => ()
            }
            PatchResult.ReRender
        }
        let attrs = HashMap<String, String>()
        attrs["class"] = "domtx-widget"
        attrs["style"] = "padding:12px;border:1px solid #e4e7ed;border-radius:8px;background:#fff;display:flex;gap:12px;align-items:center;flex-wrap:wrap"
        // 输入框需要 ref（domFocus 的目标必须是真实 input 元素），用 EP 输入框结构美化；
        // 按钮统一走组件库 Button（EP 主题色）
        let inputInner = VNode("input", [], attrs: Some(HashMap<String, String>([("type", "text"), ("placeholder", "这是一个输入框"), ("class", "el-input__inner")]))).ref("domtx-input")
        let inputWrapper = VNode("div", [inputInner], attrs: Some(HashMap<String, String>([("class", "el-input__wrapper")])))
        let inputBox = VNode("div", [inputWrapper], attrs: Some(HashMap<String, String>([("class", "el-input"), ("style", "width:220px")])))
        let root = VNode("div", [
            inputBox,
            VNode("span", [text("状态")], attrs: Some(HashMap<String, String>([("class", "domtx-status")]))).ref("domtx-status"),
            PrimaryButton("聚焦输入框").onClick(focusH),
            PrimaryButton("查询组件高度").onClick(queryH),
            PrimaryButton("序列查询 高+宽").onClick(seqH),
        ], attrs: Some(attrs)).ref("domtx-widget")
        root
    }
}
