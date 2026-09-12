package examples

import cjxt.*
import cjxt.components.*
import examples.showcase.ShowcaseState

main() {
    App()
        .configure(AppConfig(cssBundle: "/css/bundle.css?v=2"))
        .UseComponent()
        .serveStatic("/css", "public/css")
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
