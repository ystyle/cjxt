package examples

import cjxt.*
import std.env.getVariable
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
        // 端口可用 CJXT_PORT 覆盖（本机 8080 常被其它实例占用，验证时用别的端口）
        .host("0.0.0.0").port(portFromEnv()).serve()
}

/** 演示站端口：默认 8080，可用 CJXT_PORT 覆盖 */
func portFromEnv(): UInt16 {
    match (getVariable("CJXT_PORT")) {
        case Some(v) =>
            // 手写解析：非法输入一律回落到 8080（不抛异常，别让端口配置打挂演示站）
            var n: Int64 = 0
            var ok = v.size > 0
            for (b in v.toArray()) {
                let c = Int64(b)
                if (c < 48 || c > 57) {
                    ok = false
                    break
                }
                n = n * 10 + (c - 48)
            }
            if (ok && n > 0 && n < 65536) { UInt16(n) } else { 8080 }
        case None => 8080
    }
}
