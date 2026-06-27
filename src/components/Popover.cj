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

    public func placement(p: Placement): Popover {
        _props["placement"] = p.asPopper()
        this
    }

    public func effect(e: TooltipEffect): Popover {
        _props["effect"] = e.asClass()
        this
    }

    public func trigger(t: TooltipTrigger): Popover {
        _props["trigger"] = t.asString()
        this
    }

    public func width(w: Int64): Popover {
        _props["width"] = w
        this
    }

    public func showAfter(ms: Int64): Popover {
        _props["showAfter"] = ms
        this
    }

    public func hideAfter(ms: Int64): Popover {
        _props["hideAfter"] = ms
        this
    }

    public func disabled(v: Bool): Popover {
        _props["disabled"] = v
        this
    }
}
