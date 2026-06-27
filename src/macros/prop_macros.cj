macro package cjxt.macros

import std.ast.*

func extractTypeName(input: Tokens): String {
    for (i in 0..input.size) {
        if (input[i].kind == TokenKind.COLON && i + 1 < input.size) {
            let typ = input[i + 1].value
            if (typ == "Int64" || typ == "Bool" || typ == "Float64") {
                return typ
            }
            return "String"
        }
    }
    "String"
}

public macro Prop(input: Tokens): Tokens {
    let varDecl = VarDecl(input)
    setItem("prop_name", varDecl.identifier.value)
    setItem("prop_type", extractTypeName(input))
    Tokens()
}
