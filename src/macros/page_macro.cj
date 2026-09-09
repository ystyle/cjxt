macro package cjxt.macros

import std.ast.*
import std.collection.ArrayList

// 判断是否为字符串字面量 token（含多行 """..."""、#"..."# raw string、单引号/J 字符串）
func isStringKind(k: TokenKind): Bool {
    k == TokenKind.STRING_LITERAL || k == TokenKind.MULTILINE_STRING ||
    k == TokenKind.MULTILINE_RAW_STRING || k == TokenKind.SINGLE_QUOTED_STRING_LITERAL ||
    k == TokenKind.JSTRING_LITERAL
}

public macro Page(attr: Tokens, input: Tokens): Tokens {
    if (attr.size == 0) { return input }

    var path = ""
    var title = ""
    var strIdx = 0
    for (i in 0..attr.size) {
        if (isStringKind(attr[i].kind)) {
            if (strIdx == 0) {
                // trimAscii：多行 """...""" 的 .value 会带首尾换行/空格，先清理再作为 path
                path = attr[i].value.trimAscii(); strIdx = 1
            } else if (strIdx == 1) {
                title = attr[i].value.trimAscii(); strIdx = 2
            }
        }
    }
    if (path == "") { return input }

    // 收集所有 IDENTIFIER（从第一个 STRING 之后开始）
    let idents = ArrayList<String>()
    var afterStr = false
    for (i in 0..attr.size) {
        if (isStringKind(attr[i].kind)) { afterStr = true }
        if (afterStr && attr[i].kind == TokenKind.IDENTIFIER) {
            idents.add(attr[i].value)
        }
    }
    let guard = if (idents.size >= 1) { idents[0] } else { "" }
    let layout = if (idents.size >= 2) { idents[1] } else { "" }

    var className = ""
    for (i in 0..input.size) {
        if (input[i].kind == TokenKind.CLASS) {
            if (i + 1 < input.size && input[i + 1].kind == TokenKind.IDENTIFIER) {
                className = input[i + 1].value
            }
            break
        }
    }
    if (className == "") { return input }

    var reg = Tokens()
    reg = reg + Token(TokenKind.LET)
    reg = reg + Token(TokenKind.IDENTIFIER, "__reg_${className}")
    reg = reg + Token(TokenKind.ASSIGN)
    reg = reg + Token(TokenKind.IDENTIFIER, "RouteRegistry")
    reg = reg + Token(TokenKind.DOT)
    reg = reg + Token(TokenKind.IDENTIFIER, "global")
    reg = reg + Token(TokenKind.LPAREN)
    reg = reg + Token(TokenKind.RPAREN)
    reg = reg + Token(TokenKind.DOT)
    reg = reg + Token(TokenKind.IDENTIFIER, "register")
    reg = reg + Token(TokenKind.LPAREN)
    reg = reg + Token(TokenKind.STRING_LITERAL, path)
    reg = reg + Token(TokenKind.COMMA)
    reg = reg + Token(TokenKind.LCURL)
    reg = reg + Token(TokenKind.DOUBLE_ARROW)
    reg = reg + Token(TokenKind.IDENTIFIER, className)
    reg = reg + Token(TokenKind.LPAREN)
    reg = reg + Token(TokenKind.RPAREN)
    reg = reg + Token(TokenKind.RCURL)
    if (title != "") {
        reg = reg + Token(TokenKind.COMMA)
        reg = reg + Token(TokenKind.STRING_LITERAL, title)
    }
    if (guard != "") {
        reg = reg + Token(TokenKind.COMMA)
        reg = reg + Token(TokenKind.IDENTIFIER, guard)
    }
    if (layout != "") {
        reg = reg + Token(TokenKind.COMMA)
        reg = reg + Token(TokenKind.IDENTIFIER, layout)
    }
    reg = reg + Token(TokenKind.RPAREN)
    reg = reg + Token(TokenKind.NL)

    input + Token(TokenKind.NL) + reg
}
