macro package cjxt.macros

import std.ast.*
import std.collection.{HashMap, ArrayList}
import std.fs.{File, exists}

func parseJSPath(attr: Tokens): String {
    for (i in 0..attr.size) {
        if (attr[i].kind == TokenKind.IDENTIFIER && attr[i].value == "js") {
            if (i + 2 < attr.size && attr[i + 1].kind == TokenKind.COLON) {
                return attr[i + 2].value
            }
        }
    }
    ""
}

func readFileContent(path: String): String {
    if (exists(path)) {
        String.fromUtf8(File.readFrom(path))
    } else {
        let srcPath = "src/${path}"
        if (exists(srcPath)) {
            String.fromUtf8(File.readFrom(srcPath))
        } else {
            ""
        }
    }
}

func collectNames(key: String): ArrayList<String> {
    let result = ArrayList<String>()
    let msgs = getChildMessages(key)
    for (m in msgs) {
        result.add(m.getString(key))
    }
    result
}

public macro ClientComponent(attr: Tokens, input: Tokens): Tokens {
    let jsPath = parseJSPath(attr)
    let jsContent = if (jsPath != "") { readFileContent(jsPath) } else { "" }

    let classDecl = ClassDecl(input)
    let className = classDecl.identifier.value
    let compName = className

    let props = collectNames("prop_name")
    let events = collectNames("event_name")
    let methods = collectNames("method_name")

    // 构建事件列表 tokens: ArrayList<String>([])
    var evTokens = Tokens()
    evTokens = evTokens + Token(TokenKind.IDENTIFIER, "ArrayList")
    evTokens = evTokens + Token(TokenKind.LT)
    evTokens = evTokens + Token(TokenKind.IDENTIFIER, "String")
    evTokens = evTokens + Token(TokenKind.GT)
    evTokens = evTokens + Token(TokenKind.LPAREN)
    evTokens = evTokens + Token(TokenKind.LSQUARE)
    for (i in 0..events.size) {
        if (i > 0) { evTokens = evTokens + Token(TokenKind.COMMA) }
        evTokens = evTokens + Token(TokenKind.STRING_LITERAL, events[i])
    }
    evTokens = evTokens + Token(TokenKind.RSQUARE)
    evTokens = evTokens + Token(TokenKind.RPAREN)

    // 构建方法列表
    var mdTokens = Tokens()
    mdTokens = mdTokens + Token(TokenKind.IDENTIFIER, "ArrayList")
    mdTokens = mdTokens + Token(TokenKind.LT)
    mdTokens = mdTokens + Token(TokenKind.IDENTIFIER, "String")
    mdTokens = mdTokens + Token(TokenKind.GT)
    mdTokens = mdTokens + Token(TokenKind.LPAREN)
    mdTokens = mdTokens + Token(TokenKind.LSQUARE)
    for (i in 0..methods.size) {
        if (i > 0) { mdTokens = mdTokens + Token(TokenKind.COMMA) }
        mdTokens = mdTokens + Token(TokenKind.STRING_LITERAL, methods[i])
    }
    mdTokens = mdTokens + Token(TokenKind.RSQUARE)
    mdTokens = mdTokens + Token(TokenKind.RPAREN)

    var funcBody = Tokens()
    if (jsContent != "") {
        funcBody = funcBody + Token(TokenKind.IDENTIFIER, "JSRegistry")
        funcBody = funcBody + Token(TokenKind.DOT)
        funcBody = funcBody + Token(TokenKind.IDENTIFIER, "register")
        funcBody = funcBody + Token(TokenKind.LPAREN)
        funcBody = funcBody + Token(TokenKind.STRING_LITERAL, compName)
        funcBody = funcBody + Token(TokenKind.COMMA)
        funcBody = funcBody + Token(TokenKind.STRING_LITERAL, jsContent)
        funcBody = funcBody + Token(TokenKind.RPAREN)
    }
    funcBody = funcBody + Token(TokenKind.IDENTIFIER, "ClientComponentNode")
    funcBody = funcBody + Token(TokenKind.LPAREN)
    funcBody = funcBody + Token(TokenKind.STRING_LITERAL, compName)
    funcBody = funcBody + Token(TokenKind.COMMA)
    funcBody = funcBody + Token(TokenKind.IDENTIFIER, "props")
    funcBody = funcBody + Token(TokenKind.COMMA)
    funcBody = funcBody + evTokens
    funcBody = funcBody + Token(TokenKind.COMMA)
    funcBody = funcBody + mdTokens
    funcBody = funcBody + Token(TokenKind.RPAREN)

    let proxyFunc = parseDecl(quote(
        public static func $(Token(TokenKind.IDENTIFIER, className))(props: HashMap<String, String>): ClientComponentNode {
            $(funcBody)
        }
    ))

    classDecl.body.decls.add(proxyFunc)
    classDecl.toTokens()
}

public macro Prop(input: Tokens): Tokens {
    let varDecl = VarDecl(input)
    let fieldName = varDecl.identifier.value
    let fieldType = varDecl.declType.toTokens().toString().trimAscii()
    setItem("prop_name", fieldName)
    setItem("prop_type", fieldType)
    input
}

public macro Event(input: Tokens): Tokens {
    let funcDecl = FuncDecl(input)
    let funcName = funcDecl.identifier.value
    setItem("event_name", funcName)
    input
}

public macro Method(input: Tokens): Tokens {
    let funcDecl = FuncDecl(input)
    let funcName = funcDecl.identifier.value
    setItem("method_name", funcName)
    input
}
