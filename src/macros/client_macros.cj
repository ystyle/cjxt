macro package cjxt.macros

import std.ast.*
import std.collection.HashMap

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
