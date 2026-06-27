macro package cjxt.macros

import std.ast.*
import std.collection.ArrayList

public macro ClientComponent(input: Tokens): Tokens {
    let classDecl = ClassDecl(input)
    let className = classDecl.identifier.value

    let compType = parseType(quote(Component))
    classDecl.superTypes.add(compType)

    let propNames = ArrayList<String>()
    let propTypes = ArrayList<String>()
    let propMsgs = getChildMessages("Prop")
    for (m in propMsgs) {
        propNames.add(m.getString("prop_name"))
        propTypes.add(m.getString("prop_type"))
    }

    let compNameToken = Token(TokenKind.STRING_LITERAL, className)

    let propsField = parseDecl(quote(
        var _props: HashMap<String, JsonSerializable> = HashMap<String, JsonSerializable>()
    ))
    classDecl.body.decls.add(propsField)

    var initTokens = Tokens()
    initTokens = initTokens + quote(public init)
    initTokens = initTokens + Token(TokenKind.LPAREN)
    for (i in 0..propNames.size) {
        if (i > 0) { initTokens = initTokens + Token(TokenKind.COMMA) }
        let nameToken = Token(TokenKind.IDENTIFIER, propNames[i])
        let typToken = Token(TokenKind.IDENTIFIER, propTypes[i])
        initTokens = initTokens + nameToken
        initTokens = initTokens + Token(TokenKind.COLON)
        initTokens = initTokens + typToken
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

    let renderFn = parseDecl(quote(
        public func render(): IComponent {
            ClientComponentNode($(compNameToken), this._props)
        }
    ))
    classDecl.body.decls.add(renderFn)

    classDecl.toTokens()
}
