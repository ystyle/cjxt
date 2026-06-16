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

private func optKeys(m: Option<HashMap<String, String>>): ArrayList<String> {
    match (m) {
        case Some(h) => doKeys(h)
        case None => ArrayList<String>()
    }
}

private func doKeys(h: HashMap<String, String>): ArrayList<String> {
    let ks = ArrayList<String>()
    for (k in h.keys()) { ks.add(k) }
    ks
}

private func optGet(m: Option<HashMap<String, String>>, k: String): Option<String> {
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

public func diffTree(old: ComponentNode, newTree: ComponentNode, basePath: String): ArrayList<GranularPatch> {
    let patches = ArrayList<GranularPatch>()

    if (old._typ != newTree._typ || !eqOpt(old._key, newTree._key)) {
        patches.add(GranularPatch.SubtreePatch(TreePatchEntry("replace", basePath, Some(newTree))))
        return patches
    }

    // attrs
    let attrKeys = mergeKeys(optKeys(old._attrs), optKeys(newTree._attrs))
    for (key in attrKeys) {
        let oldV = optGet(old._attrs, key)
        let newV = optGet(newTree._attrs, key)
        if (oldV != newV) {
            let ap = if (basePath == "") { "/attrs/${key}" } else { "${basePath}/attrs/${key}" }
            match (newV) {
                case Some(v) => patches.add(GranularPatch.AttrPatch(AttrPatchEntry("replace", ap, Some(v))))
                case None => patches.add(GranularPatch.AttrPatch(AttrPatchEntry("remove", ap, None)))
            }
        }
    }

    // children
    let maxLen = if (old._children.size > newTree._children.size) { old._children.size } else { newTree._children.size }
    for (i in 0..maxLen) {
        let cp = if (basePath == "") { "/children/${i}" } else { "${basePath}/children/${i}" }
        if (i >= old._children.size) {
            patches.add(GranularPatch.SubtreePatch(TreePatchEntry("add", cp, Some(newTree._children[i]))))
        } else if (i >= newTree._children.size) {
            patches.add(GranularPatch.SubtreePatch(TreePatchEntry("remove", cp, None)))
        } else {
            let sub = diffTree(old._children[i], newTree._children[i], cp)
            for (p in sub) { patches.add(p) }
        }
    }

    patches
}
