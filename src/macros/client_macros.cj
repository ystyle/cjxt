macro package cjxt.macros

import std.ast.*
import std.collection.{HashMap, ArrayList}
import std.fs.{File, exists}

let _ccProps = ArrayList<(String, String)>()
let _ccEvents = ArrayList<String>()
let _ccMethods = ArrayList<String>()

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

func buildArrayList(items: ArrayList<String>): Tokens {
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

    let propNames = ArrayList<String>()
    for ((name, _) in _ccProps) { propNames.add(name) }
    _ccProps.clear()
    if (propNames.size == 0) { throw Exception("cc: no props found - @Prop might not be expanding before @ClientComponent") }

    let events = ArrayList<String>()
    for (e in _ccEvents) { events.add(e) }
    _ccEvents.clear()

    let methods = ArrayList<String>()
    for (m in _ccMethods) { methods.add(m) }
    _ccMethods.clear()

    let compNameToken = Token(TokenKind.STRING_LITERAL, className)
    let evTokens = buildArrayList(events)
    let mdTokens = buildArrayList(methods)

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
    _ccProps.add((varDecl.identifier.value, ""))
    input
}

public macro Event(input: Tokens): Tokens {
    let funcDecl = FuncDecl(input)
    _ccEvents.add(funcDecl.identifier.value)
    input
}

public macro Method(input: Tokens): Tokens {
    let funcDecl = FuncDecl(input)
    _ccMethods.add(funcDecl.identifier.value)
    input
}
