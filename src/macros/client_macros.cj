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
    let candidates = ArrayList<String>()
    candidates.add(path)
    candidates.add("src/${path}")
    candidates.add("public/${path}")
    for (c in candidates) {
        if (exists(c)) {
            return String.fromUtf8(File.readFrom(c))
        }
    }
    ""
}

func collectNames(key: String): ArrayList<String> {
    let result = ArrayList<String>()
    let msgs = getChildMessages(key)
    for (m in msgs) {
        result.add(m.getString(key))
    }
    result
}

func joinStrings(items: ArrayList<String>): String {
    if (items.size == 0) { return "" }
    var result = items[0]
    for (i in 1..items.size) {
        result = "${result}, ${items[i]}"
    }
    result
}

func buildArrayList(compName: String, items: ArrayList<String>): Tokens {
    var t = Tokens()
    t = t + Token(TokenKind.IDENTIFIER, "ArrayList")
    t = t + Token(TokenKind.LT)
    t = t + Token(TokenKind.IDENTIFIER, "String")
    t = t + Token(TokenKind.GT)
    t = t + Token(TokenKind.LPAREN)
    t = t + Token(TokenKind.LSQUARE)
    for (i in 0..items.size) {
        if (i > 0) { t = t + Token(TokenKind.COMMA) }
        t = t + Token(TokenKind.STRING_LITERAL, items[i])
    }
    t = t + Token(TokenKind.RSQUARE)
    t = t + Token(TokenKind.RPAREN)
    t
}

public macro ClientComponent(attr: Tokens, input: Tokens): Tokens {
    let jsPath = parseJSPath(attr)
    let jsContent = if (jsPath != "") { readFileContent(jsPath) } else { "" }

    let classDecl = ClassDecl(input)
    let className = classDecl.identifier.value

    let props = collectNames("prop_name")
    let events = collectNames("event_name")
    let methods = collectNames("method_name")

    let compNameToken = Token(TokenKind.STRING_LITERAL, className)
    let evTokens = buildArrayList(className, events)
    let mdTokens = buildArrayList(className, methods)

    var bodyTokens = Tokens()
    if (jsContent != "") {
        let hash = jsContent.hashCode().toString().replace("-", "0")[0..8]
        let hashToken = Token(TokenKind.STRING_LITERAL, hash)
        bodyTokens = bodyTokens + quote(App.global().addJS($(jsContent)))
        bodyTokens = bodyTokens + Token(TokenKind.NL)
        bodyTokens = bodyTokens + quote(
            ClientComponentNode($(compNameToken), props, $(evTokens), $(mdTokens)).jsHash($(hashToken))
        )
    } else {
        bodyTokens = bodyTokens + quote(
            ClientComponentNode($(compNameToken), props, $(evTokens), $(mdTokens))
        )
    }

    let proxyFunc = parseDecl(quote(
        public static func render(props: HashMap<String, String>): ClientComponentNode {
            $(bodyTokens)
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
