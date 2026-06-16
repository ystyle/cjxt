package examples

import cjxt.*

main() {
    App()
        .configure(AppConfig(cssBundle: "/css/bundle.css"))
        .serveStatic("/css", "public/css")
        .state<TabState>({ => TabState() })
        .host("0.0.0.0").port(8080).serve()
}
