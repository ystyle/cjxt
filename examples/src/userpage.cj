package examples

import cjxt.*
import cjxt.macros.*

@Page["/user/[id]"]
class UserPage <: Component {
    var userId: String = ""

    public func onMount(ctx: LifecycleContext): Unit {
        match (ctx.routeParams.get("id")) {
            case Some(id) => this.userId = id
            case None => ()
        }
    }

    public func render(): IComponent {
        div([text("用户 ID: ${this.userId}")])
    }
}
