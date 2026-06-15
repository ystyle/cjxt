package cjxt

import std.collection.{HashMap, ArrayList}

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

private func collectKeys(m: HashMap<String, String>): ArrayList<String> {
    let ks = ArrayList<String>()
    for (k in m.keys()) { ks.add(k) }
    ks
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

    if (old.typ != newTree.typ || !eqOpt(old.key, newTree.key)) {
        patches.add(PatchEntry("replace", basePath, Some(""), None))
        return patches
    }

    // attrs
    let attrKeys = mergeKeys(collectKeys(old.attrs), collectKeys(newTree.attrs))
    for (key in attrKeys) {
        let oldV = old.attrs.get(key)
        let newV = newTree.attrs.get(key)
        if (oldV != newV) {
            let ap = if (basePath == "") { "/attrs/${key}" } else { "${basePath}/attrs/${key}" }
            match (newV) {
                case Some(v) => patches.add(PatchEntry("replace", ap, Some(v), None))
                case None => patches.add(PatchEntry("remove", ap, None, None))
            }
        }
    }

    // actions
    let actKeys = mergeKeys(collectKeys(old.actions), collectKeys(newTree.actions))
    for (key in actKeys) {
        let oldA = old.actions.get(key)
        let newA = newTree.actions.get(key)
        if (oldA != newA) {
            let ap = if (basePath == "") { "/actions/${key}" } else { "${basePath}/actions/${key}" }
            match (newA) {
                case Some(v) => patches.add(PatchEntry("replace", ap, Some(v), None))
                case None => patches.add(PatchEntry("remove", ap, None, None))
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
