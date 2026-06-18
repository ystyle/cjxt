package examples

import cjxt.*
import cjxt.components.*

main() {
    App()
        .configure(AppConfig(cssBundle: "/css/bundle.css?v=2", componentsCss: "/css/element-plus/element-plus.css?v=2"))
        .serveStatic("/css", "public/css")
        .state<CounterState>({ => CounterState() })
        .state<InputsState>({ => InputsState() })
        .state<TodoState>({ => TodoState() })
        .state<ShowcaseState>({ => ShowcaseState() })
        .host("0.0.0.0").port(8080).serve()
}
