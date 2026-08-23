// 表单组件演示：Input / InputNumber / Switch / Radio / Checkbox / Rate / Select / Slider / Form
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.HashMap

public func demoInput(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础输入", [
            div([
                Input().placeholder("请输入内容").prefixIcon("search"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("禁用 / 密码", [
            div([
                Input().placeholder("禁用").disabled(),
                Input().placeholder("密码").password().suffixIcon("view"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("大号 / 可清空", [
            div([
                Input().placeholder("大号").size(ComponentSize.Large).clearable(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoInputNumber(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("计数器", [
            div([
                InputNumber().min(0).max(10).bind(st.inputNumberValue),
                InputNumber().min(0).max(100).step(5).noControls().bind(st.inputNumberValue),
                InputNumber().min(0).max(100).size(ComponentSize.Small).bind(st.inputNumberValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoSwitch(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("开关", [
            div([
                Switch().bind(st.switchValue),
                Switch().activeText("开").inactiveText("关").bind(st.switchValue),
                Switch().size(ComponentSize.Small).disabled().bind(st.switchValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoRadio(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("单选", [
            div([
                RadioGroup([
                    Radio([text("选项A")], "a"),
                    Radio([text("选项B")], "b"),
                    Radio([text("选项C")], "c").disabled(),
                ]).bind(st.radioValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                RadioGroup([
                    Radio([Button("A")], "a"),
                    Radio([Button("B")], "b"),
                ]).bind(st.radioValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoCheckbox(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("复选", [
            div([
                CheckboxGroup([
                    Checkbox([text("A")], "a"),
                    Checkbox([text("B")], "b"),
                    Checkbox([text("C")], "c").disabled(),
                ]).bind(st.checkboxValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Checkbox([text("单独复选")], "single"),
                Checkbox([text("选中并禁用")], "x").disabled(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoRate(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("评分", [
            div([
                Rate().bind(st.rateValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Rate().max(3).showText().texts(["差", "一般", "好"]).bind(st.rateValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Rate().disabled().bind(st.rateValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoSelect(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础单选", [
            div([
                Select([
                    SelectOption([text("选项A")], "a"),
                    SelectOption([text("选项B")], "b"),
                    SelectOption([text("选项C")], "c").disabled(),
                ]).placeholder("请选择").bind(st.selectValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("多选", [
            div([
                Select([
                    SelectOption([text("选项A")], "a"),
                    SelectOption([text("选项B")], "b"),
                    SelectOption([text("选项C")], "c"),
                ]).multiple().placeholder("请选择多个").bindMulti(st.multiSelectValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("可清除", [
            div([
                Select([
                    SelectOption([text("选项A")], "a"),
                    SelectOption([text("选项B")], "b"),
                ]).clearable().placeholder("可清除").bind(st.clearableValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("可搜索", [
            div([
                Select([
                    SelectOption([text("选项A")], "a"),
                    SelectOption([text("选项B")], "b"),
                    SelectOption([text("选项C")], "c"),
                ]).filterable().placeholder("输入搜索").bind(st.filterableValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("选项分组", [
            div([
                Select([
                    SelectOptionGroup([SelectOption([text("选项A")], "a"), SelectOption([text("选项B")], "b")], "水果"),
                    SelectOptionGroup([SelectOption([text("选项C")], "c"), SelectOption([text("选项D")], "d")], "蔬菜"),
                ]).placeholder("请选择分组").bind(st.groupValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("禁用", [
            div([
                Select([
                    SelectOption([text("苹果")], "apple"),
                    SelectOption([text("香蕉")], "banana"),
                    SelectOption([text("橙子")], "orange"),
                ]).placeholder("禁用").disabled(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoSlider(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("滑块", [
            Slider().min(0).max(100).bind(st.sliderValue),
            Slider().min(0).max(100).step(10).showStops().bind(st.sliderValue),
            Slider().min(0).max(100).disabled().bind(st.sliderValue),
        ]),
    ]
}

public func demoForm(st: ShowcaseState): Array<IComponent> {
    let itemUser = FormItem([Input().placeholder("请输入用户名").prefixIcon("user").bind(st.formUsername)])
        .label("用户名")
        .bind(st.formUsername)
        .rule(FormRule(required: true, message: "用户名不能为空"))
        .rule(FormRule(min: 3, message: "用户名至少3个字符"))
        .errorSignal(st.formUserError)
    let itemPwd = FormItem([Input().placeholder("请输入密码").password().prefixIcon("lock").bind(st.formPassword)])
        .label("密码")
        .bind(st.formPassword)
        .rule(FormRule(required: true, message: "密码不能为空"))
        .rule(FormRule(min: 6, message: "密码至少6个字符"))
        .errorSignal(st.formPwdError)
    let itemEmail = FormItem([Input().placeholder("请输入邮箱").prefixIcon("info-filled").bind(st.formEmail)])
        .label("邮箱")
        .bind(st.formEmail)
        .rule(FormRule(pattern: "^\\w+@\\w+\\.\\w+$", message: "邮箱格式不正确"))
        .errorSignal(st.formEmailError)
    let layout = st.formLayout.get()
    let baseForm = Form([
        itemUser, itemPwd, itemEmail,
        FormItem([Switch().activeText("启用").inactiveText("禁用").bind(st.formSwitch)]).label("状态"),
    ])
    let form = if (layout == "top") { baseForm.labelTop() } else if (layout == "inline") { baseForm.inline() } else { baseForm }

    let submitHandler: ActionHandler = { ctx: ActionContext =>
        if (form.validate()) {
            st.formError.set("")
        } else {
            st.formError.set("请填写必填字段")
        }
        PatchResult.ReRender
    }
    let defaultHandler: ActionHandler = { ctx: ActionContext => st.formLayout.set(""); PatchResult.ReRender }
    let topHandler: ActionHandler = { ctx: ActionContext => st.formLayout.set("top"); PatchResult.ReRender }
    let inlineHandler: ActionHandler = { ctx: ActionContext => st.formLayout.set("inline"); PatchResult.ReRender }

    [
        demoSection("表单（布局切换）", [
            div([
                text("布局："),
                if (layout == "") { PrimaryButton("横").size(ButtonSize.Small).onClick(defaultHandler) } else { Button("横").size(ButtonSize.Small).onClick(defaultHandler) },
                if (layout == "top") { PrimaryButton("竖").size(ButtonSize.Small).onClick(topHandler) } else { Button("竖").size(ButtonSize.Small).onClick(topHandler) },
                if (layout == "inline") { PrimaryButton("行内").size(ButtonSize.Small).onClick(inlineHandler) } else { Button("行内").size(ButtonSize.Small).onClick(inlineHandler) },
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            form,
            PrimaryButton("提交").onClick(submitHandler),
        ]),
    ]
}

// ============ Props ============

public func propsInput(): IComponent {
    div([
        propRow("placeholder", "String", "占位提示文本"),
        propRow("size", "Large | Default | Small", "输入框尺寸"),
        propRow("clearable / disabled / password", "false", "可清空 / 禁用 / 密码类型"),
        propRow("prefixIcon / suffixIcon", "String", "前缀 / 后缀图标"),
        propRow("bind(signal)", "Signal<String>", "双向绑定的信号"),
    ])
}

public func propsInputNumber(): IComponent {
    div([
        propRow("min / max / step", "Int64", "最小值 / 最大值 / 步长"),
        propRow("size", "Large | Default | Small", "计数器尺寸"),
        propRow("noControls", "false", "隐藏 +/- 按钮"),
        propRow("bind(signal)", "Signal<Int64>", "双向绑定的信号"),
    ])
}

public func propsSwitch(): IComponent {
    div([
        propRow("activeText / inactiveText", "String", "开启 / 关闭时的文本"),
        propRow("activeValue / inactiveValue", "Bool", "开启 / 关闭时的值"),
        propRow("size", "Large | Default | Small", "开关尺寸"),
        propRow("disabled", "false", "禁用状态"),
        propRow("bind(signal)", "Signal<Bool>", "双向绑定的信号"),
    ])
}

public func propsRadio(): IComponent {
    div([
        propRow("Radio(value)", "String", "单选框的值"),
        propRow("Radio.disabled", "false", "单选框禁用状态"),
        propRow("RadioGroup.bind(signal)", "Signal<String>", "单选组绑定的信号"),
    ])
}

public func propsCheckbox(): IComponent {
    div([
        propRow("Checkbox(value)", "String", "复选框的值"),
        propRow("Checkbox.disabled", "false", "复选框禁用状态"),
        propRow("CheckboxGroup.bind(signal)", "Signal<ArrayList<String>>", "复选框组绑定的信号"),
    ])
}

public func propsRate(): IComponent {
    div([
        propRow("max", "Int64 (默认 5)", "最大评分值"),
        propRow("allowHalf", "false", "是否允许半选"),
        propRow("showText", "false", "是否显示辅助文字"),
        propRow("texts", "Array<String>", "自定义辅助文字数组"),
        propRow("disabled", "false", "禁用状态"),
        propRow("bind(signal)", "Signal<Int64>", "双向绑定的信号"),
    ])
}

public func propsSelect(): IComponent {
    div([
        propRow("SelectOption(value)", "String", "选项的值"),
        propRow("SelectOption.disabled", "false", "选项禁用状态"),
        propRow("Select.placeholder", "String", "占位提示文本"),
        propRow("Select.disabled", "false", "选择器禁用状态"),
        propRow("Select.bind(signal)", "Signal<String>", "双向绑定的信号"),
    ])
}

public func propsSlider(): IComponent {
    div([
        propRow("min / max / step", "Int64", "最小值 / 最大值 / 步长"),
        propRow("showStops", "false", "是否显示间断点"),
        propRow("disabled", "false", "禁用状态"),
        propRow("bind(signal)", "Signal<Int64>", "双向绑定的信号"),
    ])
}

public func propsForm(): IComponent {
    div([
        propRow("FormItem.label", "String", "表单项标签文本"),
        propRow("FormItem.required", "false", "是否必填"),
        propRow("FormItem.error", "String", "错误提示文本"),
    ])
}
