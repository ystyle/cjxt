package examples

import cjxt.*
import cjxt.macros.*
import std.collection.{HashMap, ArrayList}

@ClientComponent[js: "../public/js/components/tooltip.js"]
class Tooltip {
    @Prop let content: String = ""
    @Prop let triggerText: String = ""

    @Event func onShow(): Unit {}
    @Event func onHide(): Unit {}
}
