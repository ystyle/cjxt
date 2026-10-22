package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}
import stdx.encoding.base64.toBase64String

// ============ Watermark 水印（对齐 Element Plus watermark） ============
//
// EP 结构（watermark.vue）：一个 `position:relative` 的容器 div，内部 append 一个
// 绝对定位、`background-repeat: repeat` 的浮层 div，背景图是 **canvas 画出来再转 base64** 的 PNG：
//   div[style="position:relative"]
//     ├─ 默认插槽内容
//     └─ div[style="position:absolute;inset:0;pointer-events:none;background-repeat:repeat;
//                 background-image:url('data:image/png;base64,...'); background-size:<w>px"]
//
// **实现差异（重要，如实说明）**：EP 在**浏览器里**用 `<canvas>` 绘制（`useClips.ts` +
// `canvas.toDataURL()`），服务端没有 canvas。因此这里改为**服务端拼 SVG，再 base64 成 data URI**：
// SVG 的 `<text>` + `rotate` 能表达与 canvas 相同的旋转文字平铺效果，且完全无需客户端参与。
// 两者产物类型不同（EP 是 image/png，这里是 image/svg+xml），CSS 用法完全一致
// （`background-image: url(data:...)` + `background-repeat: repeat` + `background-size`）。
//
// **注意**：EP 侧**没有 watermark.scss**（theme-chalk 里 0 个文件），所以水印浮层的样式
// 全部是 EP 自己在 `getMarkStyle()` 里生成的内联样式，本组件同样内联生成——这是与上游一致的
// 做法，不是"因为缺 CSS 而临时糊 inline"。
//
// **未实现**：image 型水印（EP 的 `image` prop，需要读取图片并绘制）、`useMutationObserver`
// 防篡改（EP 监听 DOM 删除/改样式后自动重建水印，属客户端机制）。

public class Watermark <: Component {
    var _children: Array<IComponent>
    var _content: String = "Cangjie UI"
    var _fontSize: Int64 = 16
    var _color: String = "rgba(0,0,0,.15)"
    var _rotate: Int64 = -22
    var _gapX: Int64 = 100
    var _gapY: Int64 = 100
    var _zIndex: Int64 = 9
    var _fontFamily: String = "sans-serif"
    var _fontWeight: String = "normal"

    public init(children: Array<IComponent>) { this._children = children }

    public func content(v: String): Watermark { this._content = v; this }
    public func fontSize(v: Int64): Watermark { this._fontSize = v; this }
    public func color(v: String): Watermark { this._color = v; this }
    // 旋转角度（EP 默认 -22 度）
    public func rotate(v: Int64): Watermark { this._rotate = v; this }
    // 水印之间的间距（EP 的 gap: [x, y]，默认 100×100）
    public func gap(x: Int64, y: Int64): Watermark { this._gapX = x; this._gapY = y; this }
    public func zIndex(v: Int64): Watermark { this._zIndex = v; this }
    public func fontFamily(v: String): Watermark { this._fontFamily = v; this }
    public func fontWeight(v: String): Watermark { this._fontWeight = v; this }

    public func render(): IComponent {
        // EP: 单行文字时 mark 尺寸 120×64；文字更长时按字数加宽（EP 用 ctx.measureText 量，
        // 服务端没有字体度量，按「字号 × 字符数」估算，宁宽勿窄，避免文字被裁）
        let markWidth = if (this._content == "") { 120 } else { maxInt(120, this.estimatedTextWidth() + 40) }
        let markHeight = 64

        let dataUri = this.buildSvgDataUri(markWidth, markHeight)
        let markStyle = "position:absolute;left:0;top:0;width:100%;height:100%;" +
            "pointer-events:none;background-repeat:repeat;" +
            "z-index:${this._zIndex};" +
            "background-image:url('${dataUri}');" +
            "background-size:${markWidth}px ${markHeight}px"

        let mark = VNode("div", [], attrs: Some(HashMap<String, String>([
            ("class", "el-watermark__mark"),
            ("style", markStyle),
        ])))
        // 浮层放在内容之后（EP 的 appendChild 顺序），容器 position:relative 使绝对定位生效
        let children = ArrayList<IComponent>()
        for (c in this._children) { children.add(c) }
        children.add(mark)

        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([
            ("class", "el-watermark"),
            ("style", "position:relative"),
        ])))
    }

    // 估算文字宽度：CJK 字符按全角（1 个字号宽），ASCII 按约 0.6 个字号宽
    func estimatedTextWidth(): Int64 {
        var width = 0
        for (r in this._content.toRuneArray()) {
            width = width + (if (isWideRune(r)) { this._fontSize } else { this._fontSize * 6 / 10 })
        }
        width
    }

    // SVG 水印：一个 markWidth × markHeight 的瓦片，文字在其中心旋转
    func buildSvgDataUri(w: Int64, h: Int64): String {
        let cx = w / 2
        let cy = h / 2
        // 文字基线对齐中心：dominant-baseline 在新浏览器可用；同时给 y 一个 half-fontSize 偏移兜底
        let escaped = escapeXml(this._content)
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"${w}\" height=\"${h}\" " +
            "viewBox=\"0 0 ${w} ${h}\">" +
            "<text x=\"${cx}\" y=\"${cy}\" " +
            "fill=\"${this._color}\" " +
            "font-size=\"${this._fontSize}\" " +
            "font-family=\"${this._fontFamily}\" " +
            "font-weight=\"${this._fontWeight}\" " +
            "text-anchor=\"middle\" " +
            "dominant-baseline=\"middle\" " +
            "transform=\"rotate(${this._rotate} ${cx} ${cy})\">" +
            "${escaped}</text></svg>"
        "data:image/svg+xml;base64,${toBase64String(svg.toArray())}"
    }
}

func maxInt(a: Int64, b: Int64): Int64 {
    if (a > b) { a } else { b }
}

// CJK / 全角字符判定（用于估算文字宽度）。
// `Rune` 不能直接 `Int64(r)`（编译报 "must have a numeric type"）——
// 取码点统一走 `UInt32(r)`，与 app.cj 的 `isJsonSpaceRune` 等既有写法一致。
func isWideRune(r: Rune): Bool {
    let c = UInt32(r)
    (c >= 0x1100 && c <= 0x115F) ||    // Hangul Jamo
    (c >= 0x2E80 && c <= 0xA4CF) ||    // CJK 部首、汉字、假名等
    (c >= 0xAC00 && c <= 0xD7A3) ||    // Hangul 音节
    (c >= 0xF900 && c <= 0xFAFF) ||    // CJK 兼容汉字
    (c >= 0xFE30 && c <= 0xFE6F) ||    // CJK 兼容形式
    (c >= 0xFF00 && c <= 0xFF60) ||    // 全角形式
    (c >= 0xFFE0 && c <= 0xFFE6)
}

// XML 文本转义（SVG 是 XML，& < > " 必须转义，否则 data URI 解析失败）
func escapeXml(s: String): String {
    var out = ""
    for (r in s.toRuneArray()) {
        let c = UInt32(r)
        if (c == 0x26) { out = "${out}&amp;" }
        else if (c == 0x3C) { out = "${out}&lt;" }
        else if (c == 0x3E) { out = "${out}&gt;" }
        else if (c == 0x22) { out = "${out}&quot;" }
        else if (c == 0x27) { out = "${out}&apos;" }
        else { out = "${out}${r}" }
    }
    out
}
