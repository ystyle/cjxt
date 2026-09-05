// 数据展示组件演示：Progress / Avatar / Empty / Descriptions / Statistic / Result
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.HashMap

public func demoProgress(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("线形进度条", [
            div([
                Progress().percentage(50),
                Progress().percentage(75).status(ProgressStatus.Success),
                Progress().percentage(100).status(ProgressStatus.Success).striped(),
                Progress().percentage(80).strokeWidth(12).textInside(),
                Progress().percentage(30).color("#f56c6c"),
            ], attrs: Some(HashMap<String, String>([("class", cls("progress-line-group"))]))),
        ]),
        demoSection("环形进度条", [
            div([
                Progress().percentage(75).kind(ProgressKind.Circle).width(100),
                Progress().percentage(65).kind(ProgressKind.Circle).width(100).status(ProgressStatus.Exception),
                Progress().percentage(80).kind(ProgressKind.Dashboard).width(100).status(ProgressStatus.Warning),
            ], attrs: Some(HashMap<String, String>([("class", cls("progress-circle-group"))]))),
        ]),
    ]
}

public func demoAvatar(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础头像", [
            div([
                Avatar().icon("user"),
                Avatar().src("https://cube.elemecdn.com/3/7c/3ea6beec64369c2642b92c6726f1epng.png"),
                Avatar().size("large").icon("user"),
                Avatar().size("small").icon("user"),
                Avatar().size("64").icon("user"),
                Avatar().shape(AvatarShape.Square).icon("user"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoEmpty(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("空状态", [
            div([
                Empty().description("暂无数据"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("带图片的自定义空状态", [
            div([
                Empty().description("没有找到相关内容"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoDescriptions(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础描述列表", [
            Descriptions()
                .title("用户信息")
                .add(DescriptionsItem().label("用户名").children([text("admin")]))
                .add(DescriptionsItem().label("手机号").children([text("138****1234")]))
                .add(DescriptionsItem().label("居住地").children([text("北京")]))
                .add(DescriptionsItem().label("角色").children([text("管理员")]))
                .add(DescriptionsItem().label("邮箱").children([text("admin@example.com")])),
        ]),
        demoSection("带边框的描述列表", [
            Descriptions()
                .border()
                .title("用户信息")
                .add(DescriptionsItem().label("用户名").children([text("admin")]))
                .add(DescriptionsItem().label("手机号").children([text("138****1234")]))
                .add(DescriptionsItem().label("居住地").children([text("北京")]))
                .add(DescriptionsItem().label("角色").children([text("管理员")]))
                .add(DescriptionsItem().label("邮箱").children([text("admin@example.com")])),
        ]),
    ]
}

public func demoStatistic(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("统计数值", [
            div([
                Statistic().title("日活跃用户").value("128,000").suffix("人"),
                Statistic().title("今日订单").value("3,256").suffix("单"),
                Statistic().title("总销售额").value(128000).prefix("¥"),
                Statistic().title("平均单价").value("1234.5").prefix("¥").precision(2),
            ], attrs: Some(HashMap<String, String>([("class", cls("statistic-row"))]))),
        ]),
    ]
}

public func demoResult(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("结果页", [
            Result()
                .title("操作成功")
                .subTitle("您已成功提交申请，请耐心等待审核")
                .icon(ResultIcon.Success),
            Result()
                .title("警告")
                .subTitle("您的操作存在风险，请确认后重试")
                .icon(ResultIcon.Warning),
            Result()
                .title("操作失败")
                .subTitle("请检查网络连接后重试")
                .icon(ResultIcon.Error),
        ]),
    ]
}

// ============ Props ============

public func propsProgress(): IComponent {
    div([
        propRow("kind", "Line | Circle | Dashboard", "进度条类型"),
        propRow("percentage", "Int64 (0-100)", "当前百分比"),
        propRow("status", "None | Success | Exception | Warning", "状态颜色"),
        propRow("strokeWidth", "Int64 (默认 6)", "进度条宽度（px）"),
        propRow("textInside", "false", "百分比文字是否在内部"),
        propRow("width", "Int64 (默认 126)", "circle 类型画布宽度"),
        propRow("showText", "Bool (默认 true)", "是否显示百分比文字"),
        propRow("color", "String", "自定义进度条颜色"),
        propRow("striped / stripedFlow", "false", "条纹 / 流动条纹"),
        propRow("indeterminate", "false", "不确定进度动画"),
        propRow("duration", "Int64 (默认 3s)", "动画持续时间"),
        propRow("strokeLinecap", "String (默认 round)", "circle 端点形状"),
    ])
}

public func propsAvatar(): IComponent {
    div([
        propRow("size", "large / small / px数字", "头像尺寸"),
        propRow("shape", "Circle | Square", "头像形状"),
        propRow("icon", "String", "图标名称"),
        propRow("src", "String", "图片 URL"),
        propRow("alt", "String", "图片 alt 文本"),
        propRow("srcSet", "String", "响应式图片 srcset"),
        propRow("fit", "Fill | Contain | Cover | None | ScaleDown", "object-fit 属性"),
        propRow("onError", "ActionHandler", "图片加载失败回调"),
    ])
}

public func propsEmpty(): IComponent {
    div([
        propRow("description", "String", "空状态描述文本"),
        propRow("image", "String", "自定义图片 URL"),
        propRow("imageSize", "String", "图片尺寸"),
        propRow("slotImage / slotDescription", "Array<IComponent>", "自定义图片 / 描述区域"),
    ])
}

public func propsDescriptions(): IComponent {
    div([
        propRow("add(item)", "Chain", "添加描述项"),
        propRow("Descriptions.border", "false", "是否带边框"),
        propRow("Descriptions.column", "Int64 (默认 3)", "列数"),
        propRow("Descriptions.direction", "Horizontal | Vertical", "排列方向"),
        propRow("Descriptions.size", "large / default / small", "尺寸"),
        propRow("Descriptions.title / extra", "String", "标题 / 额外内容"),
        propRow("Descriptions.labelWidth", "String", "标签宽度"),
        propRow("Item.label", "String", "标签文本"),
        propRow("Item.span", "Int64 (默认 1)", "跨列数"),
        propRow("Item.width / minWidth", "String", "列宽 / 最小列宽"),
        propRow("Item.align / labelAlign", "Left | Center | Right", "对齐方式"),
    ])
}

public func propsStatistic(): IComponent {
    div([
        propRow("title", "String", "数值标题"),
        propRow("value", "String | Int64", "数值内容"),
        propRow("prefix / suffix", "String", "数值前后缀文本"),
        propRow("valueStyle", "String", "数值内联样式"),
    ])
}

public func propsResult(): IComponent {
    div([
        propRow("title / subTitle", "String", "标题 / 副标题"),
        propRow("icon", "Primary | Success | Warning | Info | Error", "图标类型"),
        propRow("slotIcon / slotTitle / slotSubTitle", "Array<IComponent>", "自定义图标/标题/副标题"),
    ])
}
