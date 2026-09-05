// 基础组件演示：Button / ButtonGroup / Card / RowCol / Divider / Text / Link / Tag / Badge / Space / Icon
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.HashMap

public func demoButton(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础按钮", [
            div([
                Button("Default").dashed(),
                Button("自定义色").color("#8b5cf6"),
                Button("Default"),
                PrimaryButton("Primary"),
                SuccessButton("Success"),
                WarningButton("Warning"),
                DangerButton("Danger"),
                InfoButton("Info"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("朴素 / 圆角 / 图标", [
            div([
                Button("Plain").plain(),
                PrimaryButton("Plain").plain(),
                DangerButton("Plain").plain(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Button([Icon("search"), text("Icon")]).round(),
                PrimaryButton("Round").round(),
                DangerButton("Circle").circle().icon("delete"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("Loading / 禁用 / 文字 / 链接", [
            div([
                Button("Loading").loading(),
                PrimaryButton("Disabled").disabled(),
                Button("Text").text(),
                Button("Link").link(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoButtonGroup(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("按钮组（横向 / 纵向）", [
            div([
                ButtonGroup([PrimaryButton("上一页"), PrimaryButton("下一页")]),
                ButtonGroup([Button("左"), Button("中"), Button("右")]).kind(ButtonKind.Primary),
                ButtonGroup([Button("Top"), Button("Center"), Button("Bottom")]).direction(SpaceDirection.Vertical),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoCard(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("卡片", [
            div([
                Card([text("卡片内容")]).header("卡片标题"),
                Card([text("无标题卡片内容")]).shadow(CardShadow.Hover),
                Card([text("带底部")]).header("Header").footer("Footer"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoRowCol(st: ShowcaseState): Array<IComponent> {
    let gutter: Int64 = 16
    let cell = { label: String =>
        div([text(label)]).style("background:#f0f9ff;border:1px solid #0ea5e9;border-radius:6px;padding:12px 0;text-align:center;color:#0369a1;font-weight:600;font-size:13px")
    }
    [
        demoSection("基础栅格", [
            Row([Col([cell("span: 24")], span: 24, gutter: gutter)], gutter: gutter),
            Row([
                Col([cell("span: 12")], span: 12, gutter: gutter),
                Col([cell("span: 12")], span: 12, gutter: gutter),
            ], gutter: gutter),
            Row([
                Col([cell("span: 8")], span: 8, gutter: gutter),
                Col([cell("span: 8")], span: 8, gutter: gutter),
                Col([cell("span: 8")], span: 8, gutter: gutter),
            ], gutter: gutter),
        ]),
        demoSection("Offset", [
            Row([
                Col([cell("offset: 0")], span: 6, gutter: gutter),
                Col([cell("offset: 6")], span: 6, offset: 6, gutter: gutter),
                Col([cell("offset: 4")], span: 4, offset: 4, gutter: gutter),
            ], gutter: gutter),
        ]),
        demoSection("Justify / Align", [
            Row([
                Col([cell("start")], span: 4, gutter: gutter),
                Col([cell("center")], span: 4, gutter: gutter),
            ], gutter: gutter, justify: RowJustify.Center),
            Row([
                Col([cell("end-1")], span: 4, gutter: gutter),
                Col([cell("end-2")], span: 4, gutter: gutter),
            ], gutter: gutter, justify: RowJustify.End),
        ]),
    ]
}

public func demoDivider(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("默认分割线", [Divider()]),
        demoSection("带文字的分割线", [
            div([
                text("左侧"),
                Divider([text("Left")]).contentPosition(ContentPosition.Left),
                text("居中"),
                Divider([text("Center")]).contentPosition(ContentPosition.Center),
                text("右侧"),
                Divider([text("Right")]).contentPosition(ContentPosition.Right),
            ], attrs: Some(HashMap<String, String>([("class", cls("divider-group"))]))),
        ]),
        demoSection("垂直分割线", [
            div([
                text("Item 1"),
                Divider().direction(DividerDirection.Vertical),
                text("Item 2"),
                Divider().direction(DividerDirection.Vertical),
                text("Item 3"),
            ], attrs: Some(HashMap<String, String>([("class", cls("divider-group"))]))),
        ]),
    ]
}

public func demoText(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("文本", [
            div([
                Text([text("默认文本")]),
                Text([text("主色文本")]).kind(ComponentKind.Primary),
                Text([text("成功文本")]).kind(ComponentKind.Success),
                Text([text("危险文本")]).kind(ComponentKind.Danger),
                Text([text("大尺寸")]).size(TextSize.Large),
                Text([text("小尺寸")]).size(TextSize.Small),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                div([Text([text("这是一段会被截断的很长很长的文本内容")]).truncated()], attrs: Some(HashMap<String, String>([("class", cls("row")), ("style", "max-width:200px")]))),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoLink(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("链接", [
            div([
                Link([text("默认链接")]),
                Link([text("主色链接")]).kind(ComponentKind.Primary),
                Link([text("下划线始终")]).underline(LinkUnderline.Always),
                Link([text("无下划线")]).noUnderline(),
                Link([text("禁用链接")]).disabled(),
                Link([Icon("edit"), text("带图标")]).kind(ComponentKind.Success),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoTag(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("标签", [
            div([
                Tag([text("标签")]),
                Tag([text("成功")]).kind(ComponentKind.Success),
                Tag([text("警告")]).kind(ComponentKind.Warning),
                Tag([text("危险")]).kind(ComponentKind.Danger),
                Tag([text("信息")]).kind(ComponentKind.Info),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Tag([text("Plain")]).effect(TagEffect.Plain),
                Tag([text("Dark")]).effect(TagEffect.Dark),
                Tag([text("Round")]).round().kind(ComponentKind.Primary),
                Tag([text("Hit")]).hit().kind(ComponentKind.Success),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Tag([text("Small")]).size(TagSize.Small).kind(ComponentKind.Primary),
                Tag([text("Large")]).size(TagSize.Large).kind(ComponentKind.Danger),
                if (st.tagVisible.get()) {
                    Tag([text("可移除")]).kind(ComponentKind.Info).closable().onClose({ ctx =>
                        st.tagVisible.set(false)
                        PatchResult.ReRender
                    })
                } else {
                    let restoreHandler: ActionHandler = { ctx =>
                        st.tagVisible.set(true)
                        PatchResult.ReRender
                    }
                    PrimaryButton("恢复标签").onClick(restoreHandler)
                },
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoBadge(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("徽标", [
            div([
                Badge([Button("消息")]).value(5),
                Badge([Button("热门")]).value(120).max(99),
                Badge([Button("动态")]).dot(),
                Badge([Button("Zero")]).value(0).showZero(false),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoSpace(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("间距", [
            Space([Button("按钮1"), Button("按钮2"), Button("按钮3")]).size(16),
        ]),
    ]
}

public func demoIcon(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("图标", [
            div([
                Icon("edit"),
                Icon("delete"),
                Icon("search"),
                Icon("close"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Icon("star-filled").size("24px"),
                Icon("star").size("24px").color("#e6a23c"),
                Icon("check").size("24px").color("#67c23a"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

// ============ Props ============

public func propsButton(): IComponent {
    div([
        propRow("kind", "Default | Primary | Success | Warning | Danger | Info", "按钮类型/主题色"),
        propRow("size", "Large | Default | Small", "按钮尺寸"),
        propRow("plain / round / circle", "false", "朴素样式 / 圆角 / 圆形"),
        propRow("loading / disabled", "false", "加载中 / 禁用状态"),
        propRow("text / link / bg", "false", "文字按钮 / 链接按钮 / 背景色模式"),
        propRow("icon(name)", "String", "图标名称"),
        propRow("onClick", "(ActionContext) -> PatchResult", "点击事件"),
    ])
}

public func propsButtonGroup(): IComponent {
    div([
        propRow("children", "Array<IComponent>", "子按钮集合"),
        propRow("direction", "Horizontal | Vertical", "排列方向"),
        propRow("size / kind", "apply to children", "统一应用到子按钮的尺寸和类型"),
    ])
}

public func propsCard(): IComponent {
    div([
        propRow("header", "String | Array<IComponent>", "卡片顶部内容"),
        propRow("footer", "String | Array<IComponent>", "卡片底部内容"),
        propRow("shadow", "Always | Hover | Never", "阴影显示时机"),
        propRow("bodyStyle / bodyClass", "String", "内容区自定义样式/类名"),
    ])
}

public func propsRowCol(): IComponent {
    div([
        propRow("Row.gutter", "Int64", "栅格间隔"),
        propRow("Row.justify", "Start | End | Center | SpaceAround | SpaceBetween | SpaceEvenly", "水平对齐方式"),
        propRow("Row.align", "Top | Middle | Bottom", "垂直对齐方式"),
        propRow("Col.span", "Int64 (默认 24)", "占据的栅格数，总栅格数为 24"),
        propRow("Col.offset / push / pull", "Int64", "偏移 / 右推 / 左拉"),
    ])
}

public func propsDivider(): IComponent {
    div([
        propRow("direction", "Horizontal | Vertical", "分割线方向"),
        propRow("contentPosition", "Left | Center | Right", "内容文本位置"),
    ])
}

public func propsText(): IComponent {
    div([
        propRow("kind", "Default | Primary | Success | Warning | Danger | Info | Plain", "文本颜色类型"),
        propRow("size", "Default | Large | Small", "文本尺寸"),
        propRow("truncated", "false", "是否省略溢出文本"),
        propRow("lineClamp", "Int64", "最大显示行数"),
        propRow("tag", "String (默认 span)", "渲染的标签名"),
    ])
}

public func propsLink(): IComponent {
    div([
        propRow("kind", "Default | Primary | Success | Warning | Danger | Info", "链接颜色类型"),
        propRow("underline", "Always | Hover | Never", "下划线显示时机"),
        propRow("href / target", "String", "跳转链接 / 打开方式"),
        propRow("disabled", "false", "禁用状态"),
        propRow("icon(name)", "String", "图标名称"),
        propRow("onClick", "(ActionContext) -> PatchResult", "点击事件"),
    ])
}

public func propsTag(): IComponent {
    div([
        propRow("kind", "Default | Primary | Success | Warning | Danger | Info", "标签颜色类型"),
        propRow("size", "Default | Large | Medium | Small | Mini", "标签尺寸"),
        propRow("effect", "Dark | Light | Plain", "标签效果"),
        propRow("closable / hit / round", "false", "可关闭 / 边框高亮 / 圆角"),
        propRow("color", "String", "自定义颜色"),
    ])
}

public func propsBadge(): IComponent {
    div([
        propRow("value", "Int64 | String", "徽标数值或内容"),
        propRow("max", "Int64 (默认 99)", "数值最大值，超出显示 99+"),
        propRow("dot / hidden", "false", "小圆点模式 / 隐藏"),
        propRow("showZero", "true", "数值为 0 时是否显示"),
        propRow("kind", "Default | Primary | Success | Warning | Danger | Info", "徽标颜色类型"),
    ])
}

public func propsSpace(): IComponent {
    div([
        propRow("size", "Int64 (默认 8)", "间距大小"),
        propRow("direction", "Horizontal | Vertical", "排列方向"),
        propRow("wrap", "false", "是否自动换行"),
    ])
}

public func propsIcon(): IComponent {
    div([
        propRow("name", "String", "Element Plus 图标名称"),
    ])
}
