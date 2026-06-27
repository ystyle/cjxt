package cjxt.components

import cjxt.*
import cjxt.macros.*
import std.collection.HashMap
import stdx.encoding.json.stream.JsonSerializable

@ClientComponent
public class Tooltip {
    @Prop let content: String = ""
    @Prop let triggerText: String = ""

    public func placement(p: Placement): Tooltip {
        _props["placement"] = p.asPopper()
        this
    }

    public func effect(e: TooltipEffect): Tooltip {
        _props["effect"] = e.asClass()
        this
    }

    public func trigger(t: TooltipTrigger): Tooltip {
        _props["trigger"] = t.asString()
        this
    }

    public func showAfter(ms: Int64): Tooltip {
        _props["showAfter"] = ms
        this
    }

    public func hideAfter(ms: Int64): Tooltip {
        _props["hideAfter"] = ms
        this
    }

    public func disabled(v: Bool): Tooltip {
        _props["disabled"] = v
        this
    }
}
