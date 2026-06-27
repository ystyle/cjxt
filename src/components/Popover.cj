package cjxt.components

import cjxt.*
import cjxt.macros.*
import std.collection.HashMap
import stdx.encoding.json.stream.JsonSerializable

@ClientComponent
public class Popover {
    @Prop let content: String = ""
    @Prop let triggerText: String = ""
    @Prop let title: String = ""
}
