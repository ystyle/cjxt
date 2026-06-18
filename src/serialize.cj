package cjxt

import std.collection.HashMap
import std.io.ByteBuffer
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}

func serializeNode(c: IComponent, w: JsonWriter, handlerMap: HashMap<String, ActionHandler>): Unit {
    match (c) {
        case v: VNode =>
            w.startObject()
            w.writeName("type").writeValue(v._tag)

            // attrs
            w.writeName("attrs")
            w.writeValue(v._attrs)

            // actions — 使用 VNode 已有 ID（onClick 时分配），保证前后端一致
            w.writeName("actions")
            match (v._actions) {
                case Some(a) => w.writeValue(a)
                case None =>
                    let empty: Option<HashMap<String, String>> = None
                    w.writeValue(empty)
            }
            // 收集 handler 映射（用已有 ID）
            match (v._handlers) {
                case Some(h) => doCollectSerialize(h, handlerMap)
                case None => ()
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

public func serializeSubtree(c: IComponent, handlerMap: HashMap<String, ActionHandler>): String {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    serializeNode(c, w, handlerMap)
    w.flush()
    buf.flush()
    String.fromUtf8(buf.bytes())
}

func doCollectSerialize(m: HashMap<String, ActionHandler>, out: HashMap<String, ActionHandler>): Unit {
    for ((k, v) in m) { out.add(k, v) }
}
