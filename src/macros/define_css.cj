macro package cjxt.macros

import std.ast.*
import std.collection.{HashMap, ArrayList}
import std.fs.{File, Directory, exists, removeIfExists}
import std.process.executeWithOutput

let CACHE = "target/.css-cache"

func ensureCache(): Unit {
    if (!exists(CACHE)) {
        Directory.create(CACHE, recursive: true)
    }
}

func contentHash(s: String): String {
    s.hashCode().toString().replace("-", "0")
}

func isIdent(b: UInt8): Bool {
    (b >= 97u8 && b <= 122u8) || (b >= 65u8 && b <= 90u8) || (b >= 48u8 && b <= 57u8) || b == 45u8 || b == 95u8
}

func cssModuleTokens(entries: Array<(String, String)>): Tokens {
    var t = Tokens()
    t = t + Token(TokenKind.IDENTIFIER, "cssModule")
    t = t + Token(TokenKind.LPAREN)
    t = t + Token(TokenKind.LSQUARE)
    for ((k, v) in entries) {
        t = t + Token(TokenKind.LPAREN)
        t = t + Token(TokenKind.STRING_LITERAL, k)
        t = t + Token(TokenKind.COMMA)
        t = t + Token(TokenKind.STRING_LITERAL, v)
        t = t + Token(TokenKind.RPAREN)
        t = t + Token(TokenKind.COMMA)
    }
    t = t + Token(TokenKind.RSQUARE)
    t = t + Token(TokenKind.RPAREN)
    t
}

func processCSS(raw: String): Tokens {
    let hash = contentHash(raw)
    let map = HashMap<String, String>()
    let parts = ArrayList<String>()
    let bytes = raw.toArray()
    var i: Int64 = 0

    while (i < bytes.size) {
        if (bytes[i] == 46u8 && i + 1 < bytes.size && isIdent(bytes[i + 1])) {
            var j = i + 1
            while (j < bytes.size && isIdent(bytes[j])) { j++ }
            let name = raw[i + 1..j]
            let scoped = "${name}_${hash}"
            map.add(name, scoped)
            parts.add(".${scoped}")
            i = j
        } else {
            parts.add(String.fromUtf8([bytes[i]]))
            i++
        }
    }

    let css = String.join(parts.toArray(), delimiter: "")
    map.add("_css", css)

    let entries = ArrayList<(String, String)>()
    for ((k, v) in map) { entries.add((k, v)) }
    cssModuleTokens(entries.toArray())
}

func compile(content: String): String {
    let hash = contentHash(content)
    let scssPath = "${CACHE}/${hash}.scss"
    let cssPath = "${CACHE}/${hash}.css"

    ensureCache()
    File.writeTo(scssPath, content.toArray())

    if (!exists(cssPath)) {
        let (code, _, _) = executeWithOutput("sass", [scssPath, cssPath])
        if (code == 0) {
            String.fromUtf8(File.readFrom(cssPath))
        } else {
            removeIfExists(cssPath)
            content
        }
    } else {
        String.fromUtf8(File.readFrom(cssPath))
    }
}

public macro defineCSS(input: Tokens): Tokens {
    processCSS(compile(input[0].value))
}
