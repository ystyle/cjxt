// Popconfirm 气泡确认演示
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.HashMap

public func demoPopconfirm(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("气泡确认（Popconfirm）", [
            div([
                Popconfirm("这是一段确认文案，点“确定”后触发 onConfirm", "删除")
                    .onConfirm({ ctx =>
                        st.popconfirmResult.set("已确认删除")
                        PatchResult.ReRender
                    })
                    .onCancel({ ctx =>
                        st.popconfirmResult.set("已取消")
                        PatchResult.ReRender
                    }),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("结果：${st.popconfirmResult.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("点“删除”弹出气泡；点“取消”关闭并回调 onCancel；点“确定”回调 onConfirm")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("自定义按钮文案 / 宽度", [
            div([
                Popconfirm("此操作将发布到生产环境", "发布")
                    .width(220)
                    .confirmButtonText("发布")
                    .cancelButtonText("再想想")
                    .onConfirm({ ctx =>
                        st.popconfirmResult.set("已发布（自定义文案）")
                        PatchResult.ReRender
                    })
                    .onCancel({ ctx =>
                        st.popconfirmResult.set("再想想（自定义文案）")
                        PatchResult.ReRender
                    }),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func propsPopconfirm(): IComponent {
    div([
        propRow("Popconfirm(title, triggerText)", "String", "气泡文案 + 触发文本"),
        propRow("confirmButtonText / cancelButtonText", "String", "确定 / 取消按钮文案（默认 确定/取消）"),
        propRow("width", "Int64", "气泡宽度（默认 150）"),
        propRow("onConfirm / onCancel", "ActionHandler", "确定 / 取消回调（前端点击 → 服务端 action）"),
    ])
}
