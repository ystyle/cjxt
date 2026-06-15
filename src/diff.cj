package cjxt

import std.collection.*

// ---- type comparison ----

private func eqType(a: ComponentType, b: ComponentType): Bool {
    match (a) {
        case Div => match (b) { case Div => true; case _ => false }
        case Span => match (b) { case Span => true; case _ => false }
        case Button => match (b) { case Button => true; case _ => false }
        case Input => match (b) { case Input => true; case _ => false }
        case Form => match (b) { case Form => true; case _ => false }
        case Table => match (b) { case Table => true; case _ => false }
        case Text => match (b) { case Text => true; case _ => false }
        case Image => match (b) { case Image => true; case _ => false }
        case H1 => match (b) { case H1 => true; case _ => false }
        case H2 => match (b) { case H2 => true; case _ => false }
        case H3 => match (b) { case H3 => true; case _ => false }
        case P => match (b) { case P => true; case _ => false }
        case Select => match (b) { case Select => true; case _ => false }
        case Textarea => match (b) { case Textarea => true; case _ => false }
        case A => match (b) { case A => true; case _ => false }
        case Ul => match (b) { case Ul => true; case _ => false }
        case Li => match (b) { case Li => true; case _ => false }
    }
}

private func eqOpt(a: Option<String>, b: Option<String>): Bool {
    match (a) {
        case Some(va) => match (b) {
            case Some(vb) => va == vb
            case None => false
        }
        case None => match (b) {
            case Some(_) => false
            case None => true
        }
    }
}

// ---- Option HashMap helpers ----

private func hmapKeys(m: Option<Attributes>): ArrayList<String> {
    match (m) {
        case Some(h) => doKeys(h)
        case None => ArrayList<String>()
    }
}

private func hmapKeysA(m: Option<ActionMap>): ArrayList<String> {
    match (m) {
        case Some(h) => doKeysA(h)
        case None => ArrayList<String>()
    }
}

private func doKeys(h: Attributes): ArrayList<String> {
    let ks = ArrayList<String>()
    for (k in h.keys()) { ks.add(k) }
    ks
}

private func doKeysA(h: ActionMap): ArrayList<String> {
    let ks = ArrayList<String>()
    for (k in h.keys()) { ks.add(k) }
    ks
}

private func hmapGet(m: Option<Attributes>, k: String): Option<String> {
    match (m) {
        case Some(h) => h.get(k)
        case None => None
    }
}

private func hmapGetA(m: Option<ActionMap>, k: String): Option<String> {
    match (m) {
        case Some(h) => h.get(k)
        case None => None
    }
}

private func mergeKeys(a: ArrayList<String>, b: ArrayList<String>): ArrayList<String> {
    let ks = ArrayList<String>()
    for (k in a) { ks.add(k) }
    for (k in b) {
        if (!ks.contains(k)) { ks.add(k) }
    }
    ks
}

// ---- diff engine ----

public func diffTree(old: ComponentNode, newTree: ComponentNode, basePath: String): ArrayList<PatchEntry> {
    let patches = ArrayList<PatchEntry>()

    if (!eqType(old.typ, newTree.typ) || !eqOpt(old.key, newTree.key)) {
        patches.add(PatchEntry("replace", basePath, Some(""), None))
        return patches
    }

    // attrs
    let attrKeys = mergeKeys(hmapKeys(old.attrs), hmapKeys(newTree.attrs))
    for (key in attrKeys) {
        let oldV = hmapGet(old.attrs, key)
        let newV = hmapGet(newTree.attrs, key)
        if (oldV != newV) {
            let ap = if (basePath == "") { "/attrs/${key}" } else { "${basePath}/attrs/${key}" }
            if (newV == None) {
                patches.add(PatchEntry("remove", ap, None, None))
            } else {
                match (newV) {
                    case Some(v) => patches.add(PatchEntry("replace", ap, Some(v), None))
                    case None => ()
                }
            }
        }
    }

    // actions
    let actKeys = mergeKeys(hmapKeysA(old.actions), hmapKeysA(newTree.actions))
    for (key in actKeys) {
        let oldA = hmapGetA(old.actions, key)
        let newA = hmapGetA(newTree.actions, key)
        if (oldA != newA) {
            let ap = if (basePath == "") { "/actions/${key}" } else { "${basePath}/actions/${key}" }
            if (newA == None) {
                patches.add(PatchEntry("remove", ap, None, None))
            } else {
                match (newA) {
                    case Some(v) => patches.add(PatchEntry("replace", ap, Some(v), None))
                    case None => ()
                }
            }
        }
    }

    // children
    let maxLen = if (old.children.size > newTree.children.size) { old.children.size } else { newTree.children.size }
    for (i in 0..maxLen) {
        let cp = if (basePath == "") { "/children/${i}" } else { "${basePath}/children/${i}" }
        if (i >= old.children.size) {
            patches.add(PatchEntry("add", cp, Some(""), None))
        } else if (i >= newTree.children.size) {
            patches.add(PatchEntry("remove", cp, None, None))
        } else {
            let sub = diffTree(old.children[i], newTree.children[i], cp)
            for (p in sub) { patches.add(p) }
        }
    }

    patches
}
