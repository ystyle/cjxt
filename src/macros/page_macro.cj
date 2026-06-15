macro package cjxt.macros

import std.ast.*

public macro Page(attr: Tokens, input: Tokens): Tokens {
    if (attr.size == 0) { return input }

    // 提取路径和标题
    var path = ""
    var title = ""
    var idx = 0
    for (i in 0..attr.size) {
        if (attr[i].kind == TokenKind.STRING_LITERAL) {
            if (idx == 0) {
                path = attr[i].value
                idx = 1
            } else if (idx == 1) {
                title = attr[i].value
                idx = 2
            }
        }
    }
    if (path == "") { return input }

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

    // 构造: let __reg_X = RouteRegistry.global().register(path, { => ClassName() }[, title])
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
    reg = reg + Token(TokenKind.RPAREN)
    reg = reg + Token(TokenKind.NL)

    input + Token(TokenKind.NL) + reg
}
