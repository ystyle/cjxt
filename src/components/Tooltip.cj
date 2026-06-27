package cjxt.components

import cjxt.*
import cjxt.macros.*
import std.collection.HashMap
import stdx.encoding.json.stream.JsonSerializable

@ClientComponent
public class Tooltip {
    @Prop let content: String = ""
    @Prop let triggerText: String = ""
}
