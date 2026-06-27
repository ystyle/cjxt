package cjxt.components

import cjxt.*
import cjxt.macros.*
import std.collection.{HashMap, ArrayList}

@ClientComponent[js: "../public/js/components/tooltip.js"]
public class Tooltip {
    @Prop let content: String = ""
    @Prop let triggerText: String = ""
}
