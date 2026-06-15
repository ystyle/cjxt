macro package cjxt.macros

import std.ast.*

public macro Page(attr: Tokens, input: Tokens): Tokens {
    if (attr.size == 0) { return input }

    // 提取路径、标题和守卫
    var path = ""
    var title = ""
    var guard = ""
    var strIdx = 0
    for (i in 0..attr.size) {
        if (attr[i].kind == TokenKind.STRING_LITERAL) {
            if (strIdx == 0) {
                path = attr[i].value
                strIdx = 1
            } else if (strIdx == 1) {
                title = attr[i].value
                strIdx = 2
            }
        }
    }
    if (path == "") { return input }
    if (title == "") { strIdx = 1 }

    // 守卫函数名（第二个 STRING_LITERAL 后的 IDENTIFIER）
    if (title != "") {
        for (i in 0..attr.size) {
            if (attr[i].kind == TokenKind.STRING_LITERAL && i + 2 < attr.size && attr[i + 1].kind == TokenKind.COMMA && attr[i + 2].kind == TokenKind.IDENTIFIER) {
                guard = attr[i + 2].value
            }
        }
    }

    // 提取类名
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

    // 构造注册调用
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
    reg = reg + Token(TokenKind.RPAREN)
    reg = reg + Token(TokenKind.NL)

    input + Token(TokenKind.NL) + reg
}
