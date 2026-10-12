package examples

import cjxt.*
import cjxt.components.*
import examples.showcase.{ShowcaseState, siteCss}

main() {
    App()
        // 样式统一走 cssBlobs（见 shared.cj 的 siteCss 注释）：
        // UseComponent() 内联组件库（EP）样式，addCSS(siteCss()) 内联演示站自己的样式。
        // HTTP 与 file:// 两种承载都自动成立，不需要 cssBundle/serveStatic。
        .configure(AppConfig())
        .UseComponent()
        .addCSS(siteCss())
        .serveUpload("/_cjxt/uploads", "uploads")
        .state<CounterState>({ => CounterState() })
        .state<InputsState>({ => InputsState() })
        .state<TodoState>({ => TodoState() })
        .state<ShowcaseState>({ => ShowcaseState() })
        // 用户会话示例（/session）：令牌校验钩子 + 会话级状态
        .state<SessionDemoState>({ => SessionDemoState() })
        // 会话上下文视图：默认实现是 SessionContextState；这里换成应用自己的实现
        // （泛型约束 T <: SessionContext，把工厂收窄成接口类型，不需要反射）
        .sessionContext<SessionDemoContext>({ m => SessionDemoContext(m) })
        .auth({ t => validateDemoToken(t) })
        .host("0.0.0.0").port(8080).serve()
}
