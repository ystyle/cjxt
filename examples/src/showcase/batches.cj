// 第 1-5 批新增组件演示：Timeline / Image / Segmented / AvatarGroup /
// RadioButton / CheckboxButton / InputOtp / InputTag / Affix / Backtop /
// Anchor / PageHeader / ConfigProvider / Splitter / Carousel / Transfer /
// ColorPicker / Tour / Watermark
//
// 每个组件一个 demo 函数，签名与既有 showcase 模块一致（接收 ShowcaseState），
// 由 showcase.cj 的分发 switch 调用；属性面板单独一个 propsXxx()。
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.{HashMap, ArrayList}

// ── Timeline ──────────────────────────────────────────────────────
public func demoTimeline(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础时间线", [
            Timeline([
                TimelineItem([text("创建仓库")]).timestamp("2026-10-01 09:00"),
                TimelineItem([text("提交设计稿")]).timestamp("2026-10-05 14:30").itemType(TimelineItemType.Primary),
                TimelineItem([text("完成实现")]).timestamp("2026-10-20 18:00").itemType(TimelineItemType.Success),
                TimelineItem([text("发布上线")]).timestamp("2026-10-23 02:00").itemType(TimelineItemType.Warning),
            ]),
        ]),
        demoSection("大号节点 / 空心 / 自定义颜色", [
            Timeline([
                TimelineItem([text("大号节点")]).size(TimelineItemSize.Large).itemType(TimelineItemType.Primary),
                TimelineItem([text("空心节点")]).hollow().itemType(TimelineItemType.Success),
                TimelineItem([text("自定义颜色")]).color("#8b5cf6"),
            ]),
        ]),
        demoSection("时间戳在上方（placement）", [
            Timeline([
                TimelineItem([text("步骤一")]).timestamp("Top 位置").placement(TimelineItemPlacement.Top),
                TimelineItem([text("步骤二")]).timestamp("Top 位置").placement(TimelineItemPlacement.Top),
            ]),
        ]),
    ]
}

public func propsTimeline(st: ShowcaseState): IComponent {
    div([
        propRow("TimelineItem.timestamp", "String", "时间戳文本"),
        propRow("TimelineItem.placement", "Top | Bottom（默认 Bottom）", "时间戳位置"),
        propRow("TimelineItem.type", "Primary | Success | Warning | Danger | Info", "节点类型色"),
        propRow("TimelineItem.size", "Normal | Large", "节点尺寸"),
        propRow("TimelineItem.hollow", "-", "空心节点"),
        propRow("TimelineItem.color", "String", "自定义节点颜色"),
        propRow("TimelineItem.dot", "Array<IComponent>", "自定义节点内容，替代默认 node"),
        propRow("Timeline.mode", "String", "alternate 等布局模式"),
        propRow("Timeline.reverse", "-", "倒序渲染"),
    ])
}

// ── Image ─────────────────────────────────────────────────────────
public func demoImage(st: ShowcaseState): Array<IComponent> {
    let sample = "data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' width='240' height='140'%3E%3Crect width='240' height='140' fill='%23d9ecff'/%3E%3Ctext x='120' y='76' font-size='16' text-anchor='middle' fill='%23409eff'%3ECangjie UI%3C/text%3E%3C/svg%3E"
    [
        demoSection("基础图片（fit: cover）", [
            Image(sample).alt("示例图").fit(ImageFit.Cover).width("240px").height("140px"),
        ]),
        demoSection("不同 fit", [
            div([
                Image(sample).fit(ImageFit.Fill).width("120px").height("80px"),
                Image(sample).fit(ImageFit.Contain).width("120px").height("80px"),
                Image(sample).fit(ImageFit.Cover).width("120px").height("80px"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("错误态 / 占位态", [
            div([
                Image("https://invalid.example/no.png").error("加载失败").width("160px").height("90px"),
                Image(sample).placeholder().width("160px").height("90px"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("点击预览（简化版）", [
            Image(sample).alt("点我预览").previewSrcList([sample]).initialIndex(0).width("240px").height("140px"),
        ]),
    ]
}

public func propsImage(st: ShowcaseState): IComponent {
    div([
        propRow("src", "String", "图片地址"),
        propRow("alt", "String", "替代文本"),
        propRow("fit", "Fill | Contain | Cover | None | ScaleDown", "填充方式（内联 object-fit）"),
        propRow("lazy", "-", "原生 loading=lazy 懒加载"),
        propRow("placeholder", "-", "占位态（由调用方显式驱动）"),
        propRow("error", "String", "错误态文案"),
        propRow("preview", "-", "点击开启简化版预览"),
        propRow("previewSrcList", "Array<String>", "预览图列表"),
        propRow("initialIndex", "Int64", "预览初始索引"),
    ])
}

// ── Segmented ─────────────────────────────────────────────────────
public func demoSegmented(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础分段控制器", [
            Segmented(Segmented.textOptions(["日", "周", "月"])).bind(st.segmentedValue),
            div([text("当前值："), text(["", "日", "周", "月"][st.segmentedIndex()])])
                .style("margin-top:10px;font-size:13px;color:#606266"),
        ]),
        demoSection("带禁用项 / block 撑满", [
            Segmented([
                SegmentedOption("选项一", "a"),
                SegmentedOption("选项二", "b").disabled(),
                SegmentedOption("选项三", "c"),
            ]).bind(st.segmentedValue2).block(),
        ]),
        demoSection("垂直方向", [
            Segmented(Segmented.textOptions(["上", "中", "下"])).direction("vertical").bind(st.segmentedValue3),
        ]),
    ]
}

public func propsSegmented(st: ShowcaseState): IComponent {
    div([
        propRow("options", "Array<SegmentedOption>", "选项列表（SegmentedOption(label[, value])）"),
        propRow("bind", "Signal<String>", "选中值信号"),
        propRow("direction", "String", "horizontal | vertical"),
        propRow("block", "-", "撑满容器宽度"),
        propRow("size", "ComponentSize", "尺寸"),
        propRow("disabled", "-", "整体禁用"),
    ])
}

// ── AvatarGroup ───────────────────────────────────────────────────
public func demoAvatarGroup(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("头像组（叠放）", [
            AvatarGroup([
                Avatar().children([text("A")]),
                Avatar().children([text("B")]),
                Avatar().children([text("C")]),
                Avatar().children([text("D")]),
            ]),
        ]),
        demoSection("超出折叠（maxCollapseAvatars）", [
            AvatarGroup([
                Avatar().children([text("张")]),
                Avatar().children([text("李")]),
                Avatar().children([text("王")]),
                Avatar().children([text("赵")]),
                Avatar().children([text("钱")]),
                Avatar().children([text("孙")]),
            ]).maxCollapseAvatars(3),
        ]),
        demoSection("组级尺寸", [
            AvatarGroup([
                Avatar().children([text("X")]),
                Avatar().children([text("Y")]),
                Avatar().children([text("Z")]),
            ]).size("large"),
        ]),
    ]
}

public func propsAvatarGroup(st: ShowcaseState): IComponent {
    div([
        propRow("size", "String", "组级尺寸，补到未单独设置的头像上"),
        propRow("shape", "Circle | Square", "组级形状"),
        propRow("maxCollapseAvatars", "Int64", "超过该数量时折叠为 +N"),
        propRow("collapseClass / collapseStyle", "String", "折叠项的类名 / 样式"),
    ])
}

// ── RadioButton / CheckboxButton ─────────────────────────────────
public func demoRadioButton(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("按钮形态单选", [
            RadioGroup([
                RadioButton([text("北京")], "bj"),
                RadioButton([text("上海")], "sh"),
                RadioButton([text("广州")], "gz"),
            ]).bind(st.radioButtonValue),
        ]),
        demoSection("含禁用", [
            RadioGroup([
                RadioButton([text("启用")], "on"),
                RadioButton([text("禁用项")], "off").disabled(),
            ]).bind(st.radioButtonValue2),
        ]),
        demoSection("尺寸", [
            div([
                RadioGroup([RadioButton([text("大")], "l").size(ComponentSize.Large), RadioButton([text("大2")], "l2").size(ComponentSize.Large)]).bind(st.radioButtonValue3),
                RadioGroup([RadioButton([text("小")], "s").size(ComponentSize.Small), RadioButton([text("小2")], "s2").size(ComponentSize.Small)]).bind(st.radioButtonValue4),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func propsRadioButton(st: ShowcaseState): IComponent {
    div([
        propRow("value", "String", "该项的值"),
        propRow("disabled", "-", "禁用"),
        propRow("size", "ComponentSize", "尺寸（Large / Small）"),
        propRow("radioGroup.bind", "Signal<String>", "组选中值"),
    ])
}

public func demoCheckboxButton(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("按钮形态多选", [
            CheckboxGroup([
                CheckboxButton([text("阅读")], "read"),
                CheckboxButton([text("写作")], "write"),
                CheckboxButton([text("运动")], "sport"),
            ]).bind(st.checkboxButtonValue),
        ]),
        demoSection("含禁用", [
            CheckboxGroup([
                CheckboxButton([text("可选")], "a"),
                CheckboxButton([text("禁用")], "b").disabled(),
            ]).bind(st.checkboxButtonValue2),
        ]),
        demoSection("尺寸", [
            div([
                CheckboxGroup([CheckboxButton([text("大")], "l"), CheckboxButton([text("大2")], "l2")]).bind(st.checkboxButtonValue3),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("与普通 Checkbox 混排", [
            CheckboxGroup([
                Checkbox([text("普通勾选")], "plain"),
                CheckboxButton([text("按钮勾选")], "btn"),
            ]).bind(st.checkboxButtonValue4),
            div([text("↑ 同一组内两种形态可混排（Group 的 match 分支同时支持 Checkbox 与 CheckboxButton）")])
                .style("margin-top:8px;color:#909399;font-size:12px"),
        ]),
    ]
}

public func propsCheckboxButton(st: ShowcaseState): IComponent {
    div([
        propRow("value", "String", "该项的值"),
        propRow("disabled", "-", "禁用"),
        propRow("checkboxGroup.bind", "Signal<ArrayList<String>>", "组选中值集合"),
    ])
}

// ── InputOtp ──────────────────────────────────────────────────────
public func demoInputOtp(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("6 位验证码（默认）", [
            InputOtp().bind(st.otpValue),
        ]),
        demoSection("4 位 + 自定义外观", [
            InputOtp().length(4).kind(InputOtpType.Filled).bind(st.otpValue2),
        ]),
        demoSection("下划线风格 / 掩码", [
            div([
                InputOtp().length(4).kind(InputOtpType.Underlined).bind(st.otpValue3),
                InputOtp().length(4).mask().bind(st.otpValue4),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func propsInputOtp(st: ShowcaseState): IComponent {
    div([
        propRow("length", "Int64（默认 6）", "验证码位数"),
        propRow("kind", "Outlined | Filled | Underlined", "外观风格"),
        propRow("inputType", "String", "原生 input 的 type"),
        propRow("mask", "-", "掩码显示（password）"),
        propRow("disabled / readonly", "-", "禁用 / 只读"),
        propRow("separator", "String", "位间分隔符"),
        propRow("bind", "Signal<String>", "整体值"),
    ])
}

// ── InputTag ──────────────────────────────────────────────────────
public func demoInputTag(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础标签输入（回车添加）", [
            InputTag().placeholder("输入后按回车添加").bind(st.tagValues),
            div([text("已添加："), text(st.tagSummary())]).style("margin-top:10px;font-size:13px;color:#606266"),
        ]),
        demoSection("限制数量 / 可清空", [
            InputTag().placeholder("最多 3 个").max(3).clearable().bind(st.tagValues2),
        ]),
        demoSection("禁用", [
            InputTag().disabled().bind(st.tagValues3),
        ]),
    ]
}

public func propsInputTag(st: ShowcaseState): IComponent {
    div([
        propRow("bind", "Signal<ArrayList<String>>", "标签集合"),
        propRow("placeholder", "String", "占位文案（空列表时显示）"),
        propRow("max", "Int64", "最大标签数"),
        propRow("disabled", "-", "禁用"),
        propRow("clearable", "-", "有值时显示清空按钮"),
    ])
}

// ── Affix ─────────────────────────────────────────────────────────
public func demoAffix(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("吸顶（position: sticky，offset 10px）", [
            div([
                Affix([PrimaryButton("我是吸顶按钮")]).offset(10),
                div([text("↑ 向上滚动本页，这个按钮会吸附在距顶部 10px 处")])
                    .style("margin-left:12px;color:#909399;font-size:12px;display:inline-block"),
            ]).style("display:flex;align-items:center"),
        ]),
        demoSection("说明", [
            div([text("Affix 走纯 CSS position:sticky，无需前端 JS。受祖先元素 overflow 约束——祖先有 overflow:hidden/auto 时 sticky 会失效，这是 CSS 语义而非组件缺陷。")])
                .style("color:#909399;font-size:12px;line-height:1.7"),
        ]),
    ]
}

public func propsAffix(st: ShowcaseState): IComponent {
    div([
        propRow("offset", "Int64（默认 0）", "距顶部偏移"),
        propRow("position", "Fixed | Absolute", "Fixed → sticky；Absolute → absolute"),
        propRow("zIndex", "Int64（默认 100）", "层级"),
        propRow("bottom", "-", "改为贴底部"),
    ])
}

// ── Backtop ───────────────────────────────────────────────────────
public func demoBacktop(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("回到顶部按钮", [
            div([text("Backtop 通常固定在页面右下角（见本页右下角圆形按钮）。这里演示组件本身的结构：")])
                .style("color:#606266;font-size:13px;margin-bottom:12px"),
            div([Backtop()]).style("position:relative;height:120px;border:1px dashed #dcdfe6;border-radius:6px;background:#fafafa"),
        ]),
        demoSection("说明", [
            div([text("实现走原生 <a href=\"#\"> 锚点回顶，零前端 JS。未做 visibilityHeight 显隐（纯客户端滚动状态，服务端读不到），故恒显示。")])
                .style("color:#909399;font-size:12px;line-height:1.7"),
        ]),
    ]
}

public func propsBacktop(st: ShowcaseState): IComponent {
    div([
        propRow("right / bottom", "String（默认 40px）", "距右下角距离"),
        propRow("href", "String（默认 #）", "回顶锚点"),
        propRow("icon", "String", "图标名（默认 arrow-up）"),
        propRow("onClick", "ActionHandler", "旁路回调"),
    ])
}

// ── Anchor ────────────────────────────────────────────────────────
public func demoAnchor(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("纵向锚点导航", [
            div([
                div([
                    Anchor([
                        AnchorLink("第一节", "#anchor-sec-1"),
                        AnchorLink("第二节", "#anchor-sec-2"),
                        AnchorLink("第三节", "#anchor-sec-3"),
                    ]).current("#anchor-sec-1"),
                ]).style("width:160px;flex-shrink:0"),
                div([
                    div([text("第一节")]).style("height:80px;background:#f0f9ff;border-radius:6px;padding:12px;margin-bottom:8px"),
                    div([text("第二节")]).style("height:80px;background:#f0f9ff;border-radius:6px;padding:12px;margin-bottom:8px"),
                    div([text("第三节")]).style("height:80px;background:#f0f9ff;border-radius:6px;padding:12px"),
                ]).style("flex:1"),
            ]).style("display:flex;gap:20px"),
        ]),
        demoSection("横向锚点", [
            Anchor([
                AnchorLink("首页", "#h1"),
                AnchorLink("产品", "#h2"),
                AnchorLink("关于", "#h3"),
            ]).direction(AnchorDirection.Horizontal),
        ]),
    ]
}

public func propsAnchor(st: ShowcaseState): IComponent {
    div([
        propRow("AnchorLink(title, href)", "String, String", "锚点项"),
        propRow("direction", "Vertical | Horizontal", "方向"),
        propRow("current", "String", "当前激活的 href"),
        propRow("bindAnchorCurrent", "Signal<String>", "激活项信号驱动"),
        propRow("offset", "Int64", "跳转偏移（scroll-margin-top）"),
    ])
}

// ── PageHeader ────────────────────────────────────────────────────
public func demoPageHeader(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础页头", [
            PageHeader().title("详情页").content("这是页面内容描述"),
        ]),
        demoSection("带返回按钮", [
            PageHeader().title("用户管理").content("编辑用户信息").onBack({
                ctx => st.pageHeaderMsg.set("点击了返回（服务端回调已执行）")
                PatchResult.ReRender
            }),
            div([text(st.pageHeaderMsg.get())]).style("margin-top:8px;color:#909399;font-size:12px"),
        ]),
    ]
}

public func propsPageHeader(st: ShowcaseState): IComponent {
    div([
        propRow("title", "String", "标题（默认「返回」）"),
        propRow("content", "String", "内容描述"),
        propRow("onBack", "ActionHandler", "返回动作；未给时不挂 click"),
        propRow("back icon", "-", "返回箭头图标"),
    ])
}

// ── ConfigProvider ────────────────────────────────────────────────
public func demoConfigProvider(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("尺寸注入（size: small → --el-component-size:24px）", [
            ConfigProvider([
                Input().placeholder("输入框高度由 --el-component-size 决定"),
            ]).size(ComponentSize.Small),
            div([text("↑ 注入 small 后输入框高度应为 24px")])
                .style("margin-top:6px;color:#909399;font-size:12px"),
        ]),
        demoSection("默认尺寸（不注入）", [
            ConfigProvider([
                Input().placeholder("默认 32px"),
            ]),
            div([text("↑ 未注入时继承主题默认 32px")])
                .style("margin-top:6px;color:#909399;font-size:12px"),
        ]),
        demoSection("说明", [
            div([text("EP 的 ConfigProvider 靠 provide/inject，不输出元素；cjxt 无上下文通道，改用 CSS 变量继承，因此多一层 .el-config-provider 包裹元素。这是架构适配，不是对齐疏漏。")])
                .style("color:#909399;font-size:12px;line-height:1.7"),
            div([text("注意：--el-component-size 只被 Input / Radio / InputNumber 等消费（--el-input-height: var(--el-component-size)）；Button 的尺寸走 el-button--small 类，不受该变量影响。")])
                .style("color:#909399;font-size:12px;line-height:1.7"),
        ]),
    ]
}

public func propsConfigProvider(st: ShowcaseState): IComponent {
    div([
        propRow("size", "Small | Default | Large", "全局尺寸（--el-component-size）"),
        propRow("zIndex", "Int64", "弹层层级（--el-index-popper）"),
        propRow("cssVars", "HashMap<String, String>", "任意 --el-* 变量覆盖"),
    ])
}

// ── Splitter ──────────────────────────────────────────────────────
public func demoSplitter(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("水平分割（两栏）", [
            div([Splitter([
                SplitterPanel([div([text("左侧面板")]).style("padding:16px;background:#f0f9ff;height:100%")]).size("40%"),
                SplitterPanel([div([text("右侧面板")]).style("padding:16px;background:#e1f3d8;height:100%")]),
            ]).layout(SplitterLayout.Horizontal).sizes(st.splitterSizesH)]).style("height:120px;border:1px solid #dcdfe6;border-radius:6px;overflow:hidden"),
        ]),
        demoSection("垂直分割", [
            div([Splitter([
                SplitterPanel([div([text("上面板")]).style("padding:12px;background:#f0f9ff;height:100%")]).size("50%"),
                SplitterPanel([div([text("下面板")]).style("padding:12px;background:#e1f3d8;height:100%")]),
            ]).layout(SplitterLayout.Vertical).sizes(st.splitterSizesV)]).style("height:140px;border:1px solid #dcdfe6;border-radius:6px;overflow:hidden"),
        ]),
        demoSection("说明", [
            div([text("拖拽已支持：pointermove 按容器比例算面板尺寸 → 标准 bind 消息回传（rAF 节流）→ 服务端写 sizes 信号重渲染。纯 bind 往返，不新增协议消息。dragger 也可聚焦后用方向键 ±16px 调整。")])
                .style("color:#909399;font-size:12px;line-height:1.7"),
        ]),
    ]
}

public func propsSplitter(st: ShowcaseState): IComponent {
    div([
        propRow("layout", "Horizontal | Vertical", "分割方向"),
        propRow("SplitterPanel.size", "String", "面板尺寸（flex-basis）"),
        propRow("SplitterPanel.min / max", "String", "最小 / 最大尺寸"),
        propRow("collapsible", "-", "可折叠"),
    ])
}

// ── Carousel ──────────────────────────────────────────────────────
public func demoCarousel(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础轮播（手动切换指示点）", [
            div([Carousel([
                CarouselItem([div([text("第 1 张")]).style("display:flex;align-items:center;justify-content:center;height:100%;background:#d9ecff;color:#409eff;font-size:18px")]),
                CarouselItem([div([text("第 2 张")]).style("display:flex;align-items:center;justify-content:center;height:100%;background:#e1f3d8;color:#67c23a;font-size:18px")]),
                CarouselItem([div([text("第 3 张")]).style("display:flex;align-items:center;justify-content:center;height:100%;background:#faecd8;color:#e6a23c;font-size:18px")]),
            ]).bind(st.carouselIndex)]).style("height:180px;border-radius:6px;overflow:hidden"),
            div([text("当前第 "), text("${st.carouselIndex.get() + 1}"), text(" 张")]).style("margin-top:8px;font-size:13px;color:#606266"),
        ]),
        demoSection("纵向方向", [
            div([Carousel([
                CarouselItem([div([text("纵向 1")]).style("display:flex;align-items:center;justify-content:center;height:100%;background:#d9ecff;color:#409eff")]),
                CarouselItem([div([text("纵向 2")]).style("display:flex;align-items:center;justify-content:center;height:100%;background:#e1f3d8;color:#67c23a")]),
            ]).direction(CarouselDirection.Vertical).bind(st.carouselIndex2)]).style("height:160px;border-radius:6px;overflow:hidden"),
        ]),
        demoSection("指示器位置 / 关闭箭头", [
            div([Carousel([
                CarouselItem([div([text("Outside 指示器")]).style("display:flex;align-items:center;justify-content:center;height:100%;background:#faecd8;color:#e6a23c")]),
                CarouselItem([div([text("第 2 页")]).style("display:flex;align-items:center;justify-content:center;height:100%;background:#d9ecff;color:#409eff")]),
            ]).indicatorPosition("outside").arrow("never").bind(st.carouselIndex3)]).style("height:140px;border-radius:6px;overflow:hidden"),
        ]),
        demoSection("卡片模式（type: card）", [
            div([Carousel([
                CarouselItem([div([text("卡片 1")]).style("display:flex;align-items:center;justify-content:center;height:100%;background:#d9ecff;color:#409eff")]),
                CarouselItem([div([text("卡片 2")]).style("display:flex;align-items:center;justify-content:center;height:100%;background:#e1f3d8;color:#67c23a")]),
                CarouselItem([div([text("卡片 3")]).style("display:flex;align-items:center;justify-content:center;height:100%;background:#faecd8;color:#e6a23c")]),
            ]).carouselType(CarouselType.Card).bind(st.carouselIndex4)]).style("height:160px;border-radius:6px;overflow:hidden"),
        ]),
        demoSection("说明（能力边界）", [
            div([text("无 autoplay——EP 用客户端 setInterval 推进，cjxt 组件无时钟；DOM 与 data-carousel 标记已备好供后续接线。")])
                .style("color:#909399;font-size:12px"),
        ]),
    ]
}

public func propsCarousel(st: ShowcaseState): IComponent {
    div([
        propRow("bind", "Signal<Int64>", "当前索引"),
        propRow("direction", "Horizontal | Vertical", "方向"),
        propRow("type", "Card | Default", "卡片模式"),
        propRow("loop", "-", "循环"),
        propRow("indicatorPosition", "String", "指示器位置"),
    ])
}

// ── Transfer ──────────────────────────────────────────────────────
public func demoTransfer(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础穿梭框", [
            Transfer(ArrayList<TransferOption>([
                TransferOption("1", "选项一"),
                TransferOption("2", "选项二"),
                TransferOption("3", "选项三"),
                TransferOption("4", "选项四"),
            ])).bind(st.transferValues),
        ]),
        demoSection("自定义标题 / 按钮文案", [
            Transfer(ArrayList<TransferOption>([
                TransferOption("1", "选项一"),
                TransferOption("2", "选项二"),
                TransferOption("3", "选项三"),
            ])).titles("待选", "已选").buttonTexts("移入", "移出").bind(st.transferValues2),
        ]),
        demoSection("含禁用项", [
            Transfer(ArrayList<TransferOption>([
                TransferOption("1", "可用"),
                TransferOption("2", "禁用项", disabled: true),
                TransferOption("3", "可用二"),
            ])).bind(st.transferValues3),
        ]),
        demoSection("说明（能力边界）", [
            div([text("无 filterable / virtualScroll——需输入过滤与虚拟列表。交互上把 EP 的「两侧勾选+箭头」两步压成「勾选即移动」一步，避免两份状态打架。")])
                .style("color:#909399;font-size:12px;line-height:1.7"),
        ]),
    ]
}

public func propsTransfer(st: ShowcaseState): IComponent {
    div([
        propRow("options", "Array<TransferItem>", "数据源"),
        propRow("bind", "Signal<ArrayList<String>>", "已选中的 key 集合"),
        propRow("titles", "Array<String>", "两侧标题"),
    ])
}

// ── ColorPicker ───────────────────────────────────────────────────
public func demoColorPicker(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("预设色板选择", [
            div([
                ColorPicker().bind(st.colorValue),
                div([text("当前颜色："), text(st.colorValue.get())])
                    .style("margin-left:12px;font-size:13px;color:#606266;display:inline-block;vertical-align:middle"),
            ]).style("display:flex;align-items:center"),
        ]),
        demoSection("不同尺寸", [
            div([
                ColorPicker().size(ComponentSize.Small).bind(st.colorValue2),
                ColorPicker().bind(st.colorValue3),
                ColorPicker().size(ComponentSize.Large).bind(st.colorValue4),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("说明", [
            div([text("无 showAlpha / 自由取色——EP 面板是饱和度区拖拽 + 色相条（需大量前端指针交互），改为预设色板网格 + 前端原生取色。")])
                .style("color:#909399;font-size:12px;line-height:1.7"),
        ]),
    ]
}

public func propsColorPicker(st: ShowcaseState): IComponent {
    div([
        propRow("bind", "Signal<String>", "颜色值（hex）"),
        propRow("size", "Small | Default | Large", "尺寸"),
        propRow("disabled", "-", "禁用"),
    ])
}

// ── Tour ──────────────────────────────────────────────────────────
public func demoTour(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("漫游引导（居中弹层）", [
            PrimaryButton("开始引导").onClick(tourStartHandler(st)),
            Tour([
                TourStep("第一步", "这是引导的第一步内容"),
                TourStep("第二步", "这是引导的第二步内容"),
                TourStep("第三步", "最后一步，点击完成结束"),
            ]).bindVisible(st.tourVisible).onFinish({
                ctx => st.tourVisible.set(false)
                PatchResult.ReRender
            }),
        ]),
        demoSection("可关闭 / 自定义按钮文案", [
            PrimaryButton("开始（可关闭）").onClick(tourStartHandler2(st)),
            Tour([
                TourStep("步骤一", "带关闭按钮，可随时退出"),
                TourStep("步骤二", "按钮文案已自定义"),
            ]).bindVisible(st.tourVisible2).showClose(true).buttonTexts("上一步", "下一步", "我知道了")
                .bindCurrent(st.tourCurrent).onClose({
                    ctx => st.tourVisible2.set(false)
                    PatchResult.ReRender
                }),
        ]),
        demoSection("说明（能力边界）", [
            div([text("不定位到目标元素——服务端拿不到目标 rect（EP 靠客户端 FloatingUI 测量），内容改为 position:fixed 居中；target 仍落到 data-tour-target 供后续前端接线。")])
                .style("color:#909399;font-size:12px;line-height:1.7"),
        ]),
    ]
}

public func propsTour(st: ShowcaseState): IComponent {
    div([
        propRow("visible", "Signal<Bool>", "是否显示"),
        propRow("steps", "Array<TourStep>", "步骤列表"),
        propRow("placement", "Top | Bottom | Left | Right | Center", "弹层位置"),
        propRow("onFinish", "ActionHandler", "结束回调"),
    ])
}

// ── Watermark ─────────────────────────────────────────────────────
public func demoWatermark(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("文字水印", [
            Watermark([div([text("水印覆盖区域内容")]).style("padding:30px;height:120px")])
                .content("Cangjie UI"),
        ]),
        demoSection("自定义颜色 / 字号 / 旋转", [
            Watermark([div([text("自定义样式水印")]).style("padding:30px;height:120px")])
                .content("内部资料").color("rgba(64,158,255,0.3)").fontSize(18).rotate(-30),
        ]),
        demoSection("说明", [
            div([text("用 SVG data URI 而非 canvas——服务端无 canvas，SVG 的 text+rotate 等价。无 image 型水印、无 MutationObserver 防篡改。")])
                .style("color:#909399;font-size:12px;line-height:1.7"),
        ]),
    ]
}

public func propsWatermark(st: ShowcaseState): IComponent {
    div([
        propRow("content", "String", "水印文本"),
        propRow("color", "String", "颜色"),
        propRow("fontSize", "Int64", "字号"),
        propRow("rotate", "Int64", "旋转角度"),
        propRow("gap", "String", "间距"),
        propRow("zIndex", "Int64（默认 9）", "层级"),
    ])
}

// onClick 存在 ActionHandler / (ActionContext)->Unit 两个重载，直接写 lambda 会歧义；
// 先声明成 ActionHandler 再传入（AGENTS.md 记过的老坑）。
func tourStartHandler(st: ShowcaseState): ActionHandler {
    let h: ActionHandler = { ctx => st.tourVisible.set(true); PatchResult.ReRender }
    h
}

func tourStartHandler2(st: ShowcaseState): ActionHandler {
    let h: ActionHandler = { ctx => st.tourVisible2.set(true); st.tourCurrent.set(0); PatchResult.ReRender }
    h
}
