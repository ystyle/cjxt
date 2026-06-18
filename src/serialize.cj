package cjxt

import std.collection.HashMap
import std.io.ByteBuffer
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}

func serializeNode(c: Component, w: JsonWriter, handlerMap: HashMap<String, ActionHandler>): Unit {
    match (c) {
        case v: VNode =>
            w.startObject()
            w.writeName("type").writeValue(v._tag)

            // attrs
            w.writeName("attrs")
            w.writeValue(v._attrs)

            // actions — 从 handlers 分配新 ID，同时写入 handlerMap
            w.writeName("actions")
            match (v._handlers) {
                case Some(h) =>
                    let actionMap = HashMap<String, String>()
                    for ((ev, handler) in h) {
                        let id = nextHid()
                        actionMap[ev] = id
                        handlerMap[id] = handler
                    }
                    w.writeValue(actionMap)
                case None =>
                    let empty: Option<HashMap<String, String>> = None
                    w.writeValue(empty)
            }

            // children
            w.writeName("children")
            w.startArray()
            for (child in v._children) {
                serializeNode(child, w, handlerMap)
            }
            w.endArray()

            w.endObject()

        case t: TextNode =>
            w.startObject()
            w.writeName("type").writeValue("text")
            w.writeName("attrs")
            w.startObject()
            w.writeName("text").writeValue(t._text)
            w.endObject()
            w.endObject()

        case f: FragmentNode =>
            w.startObject()
            w.writeName("type").writeValue("fragment")
            w.writeName("children")
            w.startArray()
            for (child in f._children) {
                serializeNode(child, w, handlerMap)
            }
            w.endArray()
            w.endObject()

        case e: EmptyNode =>
            w.startObject()
            w.writeName("type").writeValue("empty")
            w.endObject()

        case other =>
            serializeNode(other.render(), w, handlerMap)
    }
}

public func serializeSubtree(c: Component, handlerMap: HashMap<String, ActionHandler>): String {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    serializeNode(c, w, handlerMap)
    w.flush()
    buf.flush()
    String.fromUtf8(buf.bytes())
}
