package examples

import cjxt.*

main() {
    App()
        .state<TabState>({ => TabState() })
        .host("0.0.0.0").port(8080).serve()
}
