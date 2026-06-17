package examples

import cjxt.*
import cjxt.components.*

main() {
    App()
        .configure(AppConfig(cssBundle: "/css/bundle.css", componentsCss: "/css/element-plus/button.css"))
        .serveStatic("/css", "public/css")
        .state<CounterState>({ => CounterState() })
        .state<InputsState>({ => InputsState() })
        .state<TodoState>({ => TodoState() })
        .host("0.0.0.0").port(8080).serve()
}
