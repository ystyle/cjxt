package examples

import cjxt.*
import cjxt.macros.*
import std.collection.{HashMap, ArrayList}

@ClientComponent[js: "../public/js/components/popover.js"]
class Popover {
    @Prop let content: String = ""
    @Prop let triggerText: String = ""
    @Prop let title: String = ""
}
