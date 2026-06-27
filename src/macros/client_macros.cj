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

    // 添加 <: Component 使类可被当作 IComponent 使用
    let compType = parseType(quote(Component))
    classDecl.superTypes.add(compType)

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

    // 生成 _props 字段
    let propsField = parseDecl(quote(
        var _props: HashMap<String, String> = HashMap<String, String>()
    ))
    classDecl.body.decls.add(propsField)

    // 生成 init 构造器: init(content: String, triggerText: String) { ... }
    var initTokens = Tokens()
    initTokens = initTokens + quote(public init)
    initTokens = initTokens + Token(TokenKind.LPAREN)
    for (i in 0..propNames.size) {
        if (i > 0) { initTokens = initTokens + Token(TokenKind.COMMA) }
        initTokens = initTokens + Token(TokenKind.IDENTIFIER, propNames[i])
        initTokens = initTokens + Token(TokenKind.COLON)
        initTokens = initTokens + Token(TokenKind.IDENTIFIER, "String")
    }
    initTokens = initTokens + Token(TokenKind.RPAREN)
    initTokens = initTokens + Token(TokenKind.LCURL)
    initTokens = initTokens + Token(TokenKind.NL)
    for (name in propNames) {
        initTokens = initTokens + quote(_props[$(Token(TokenKind.STRING_LITERAL, name))] = $(Token(TokenKind.IDENTIFIER, name)))
        initTokens = initTokens + Token(TokenKind.NL)
    }
    initTokens = initTokens + Token(TokenKind.RCURL)

    let initFn = parseDecl(initTokens)
    classDecl.body.decls.add(initFn)

    // 生成 render 方法: 使用 this._props 构建 ClientComponentNode
    var renderBody = Tokens()
    if (jsContent != "") {
        let hash = jsContent.hashCode().toString().replace("-", "0")[0..8]
        let hashToken = Token(TokenKind.STRING_LITERAL, hash)
        renderBody = renderBody + quote(App.global().addJS($(jsContent)))
        renderBody = renderBody + Token(TokenKind.NL)
        renderBody = renderBody + quote(ClientComponentNode($(compNameToken), this._props, $(evTokens), $(mdTokens)).jsHash($(hashToken)))
    } else {
        renderBody = renderBody + quote(ClientComponentNode($(compNameToken), this._props, $(evTokens), $(mdTokens)))
    }

    let renderFn = parseDecl(quote(
        public func render(): IComponent {
            $(renderBody)
        }
    ))
    classDecl.body.decls.add(renderFn)
    classDecl.toTokens()
}
