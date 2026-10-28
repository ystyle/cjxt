// 站点布局（`@Page` 的第四个参数）
//
// 目的：把「页头/导航 + 内容区」从每个页面里抽出来，交给框架的 layout 机制统一套。
//
// 改造前：每个页面在 render() 里自己调 `renderTabs("/xxx")` 手动贴导航，
// 于是每加一个页面都要动所有页面的 active 判断；layout 机制虽早已实现，
// 却因为渲染路径的缺陷（HTTP 首渲不套 layout）而没人用。
//
// 改造后：`@Page["/path", "标题", guard, siteLayout]`，页面只渲染自己的正文。
// 导航项集中在 NAV_ITEMS 一处，active 由 layout 按**当前请求路径**判断。
package examples

import cjxt.*
import cjxt.components.*
import std.collection.{ArrayList, HashMap}
import examples.showcase.cls

/** 导航项：路径 + 标题 */
let NAV_ITEMS: Array<(String, String)> = [
    ("/", "Counter"),
    ("/inputs", "Inputs"),
    ("/todo", "Todo"),
    ("/showcase", "组件库"),
    ("/session", "用户会话"),
]

/**
 * 站点布局：统一页头 + 导航 + 内容区。
 *
 * @param page 页面自己渲染的内容
 */
public func siteLayout(page: IComponent): IComponent {
    let kids = ArrayList<IComponent>()
    kids.add(siteHeader())
    kids.add(div([page], attrs: Some(HashMap<String, String>([("class", cls("container"))]))))
    div(kids.toArray())
}

/** 页头：站点名 + 导航 */
func siteHeader(): IComponent {
    let kids = ArrayList<IComponent>()
    kids.add(div([text("cjxt 演示站")],
        attrs: Some(HashMap<String, String>([("class", cls("brand"))]))))
    let tabs = ArrayList<IComponent>()
    for ((path, title) in NAV_ITEMS) {
        tabs.add(navTab(path, title, isActive(path)))
    }
    kids.add(div(tabs.toArray(), attrs: Some(HashMap<String, String>([("class", cls("tabs"))]))))
    div(kids.toArray(), attrs: Some(HashMap<String, String>([("class", cls("site-header"))])))
}

/**
 * 当前路径是否命中某导航项。
 *
 * 路径来自框架的 `layoutPath()` —— `LayoutFn` 的签名只有 `(IComponent) -> IComponent`，
 * 拿不到"这是哪一页"，而导航高亮必须知道。所以框架在应用 layout 期间把路径
 * 放进渲染期临时变量（见 app.cj 的 applyLayout / layoutPath）。
 *
 * 前缀匹配：`/session/login`、`/session/profile` 都点亮「用户会话」；
 * 根路径 `/` 只在恰好是 `/` 时点亮（否则任何页面都会命中）。
 */
func isActive(itemPath: String): Bool {
    let cur = layoutPath()
    if (cur == "") { return false }
    if (itemPath == "/") { return cur == "/" }
    cur == itemPath || cur.startsWith(itemPath + "/")
}

/** 导航按钮 */
func navTab(path: String, title: String, active: Bool): IComponent {
    let clsName = if (active) { cls("tab") + " " + cls("active") } else { cls("tab") }
    button([text(title)], attrs: Some(HashMap<String, String>([("class", clsName)])))
        .onClick({ ctx =>
            ctx.route.push(path)
            PatchResult.ReRender
        })
}

/**
 * 无守卫：`@Page` 的 layout 是**第五个**参数，要指定它必须先给 guard 占位。
 *
 * 这几个演示页都是公开的，所以守卫恒放行。
 */
public func noGuard(_: HashMap<String, String>): Option<String> {
    None
}
