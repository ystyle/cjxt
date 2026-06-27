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
    let propMsgs = getChildMessages("Prop")
    for (m in propMsgs) {
        propNames.add(m.getString("prop_name"))
    }

    let events = ArrayList<String>()
    let evMsgs = getChildMessages("Event")
    for (m in evMsgs) {
        events.add(m.getString("event_name"))
    }

    let methods = ArrayList<String>()
    let mdMsgs = getChildMessages("Method")
    for (m in mdMsgs) {
        methods.add(m.getString("method_name"))
    }

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
