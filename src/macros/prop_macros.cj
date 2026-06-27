macro package cjxt.macros

import std.ast.*

public macro Prop(input: Tokens): Tokens {
    let varDecl = VarDecl(input)
    setItem("prop_name", varDecl.identifier.value)
    input
}

public macro Event(input: Tokens): Tokens {
    let funcDecl = FuncDecl(input)
    setItem("event_name", funcDecl.identifier.value)
    input
}

public macro Method(input: Tokens): Tokens {
    let funcDecl = FuncDecl(input)
    setItem("method_name", funcDecl.identifier.value)
    input
}
