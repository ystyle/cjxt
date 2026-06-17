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

public func diffTree(old: Component, newTree: Component, basePath: String): ArrayList<GranularPatch> {
    let patches = ArrayList<GranularPatch>()

    match (old) {
        case o: VNode => match (newTree) {
            case n: VNode => diffVNode(o, n, basePath, patches)
            case _ => patches.add(GranularPatch.SubtreePatch(TreePatchEntry("replace", basePath, Some(newTree))))
        }
        case o: TextNode => match (newTree) {
            case n: TextNode => diffText(o, n, basePath, patches)
            case _ => patches.add(GranularPatch.SubtreePatch(TreePatchEntry("replace", basePath, Some(newTree))))
        }
        case o: FragmentNode => match (newTree) {
            case n: FragmentNode => diffFragment(o, n, basePath, patches)
            case _ => patches.add(GranularPatch.SubtreePatch(TreePatchEntry("replace", basePath, Some(newTree))))
        }
        case _ => patches.add(GranularPatch.SubtreePatch(TreePatchEntry("replace", basePath, Some(newTree))))
    }

    patches
}

private func diffVNode(old: VNode, newTree: VNode, basePath: String, patches: ArrayList<GranularPatch>): Unit {
    if (old._tag != newTree._tag || !eqOpt(old._key, newTree._key)) {
        patches.add(GranularPatch.SubtreePatch(TreePatchEntry("replace", basePath, Some(newTree))))
        return
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
    diffChildren(old._children, newTree._children, basePath, patches)
}

private func diffText(old: TextNode, newTree: TextNode, basePath: String, patches: ArrayList<GranularPatch>): Unit {
    if (old._text != newTree._text) {
        let ap = if (basePath == "") { "/attrs/text" } else { "${basePath}/attrs/text" }
        patches.add(GranularPatch.AttrPatch(AttrPatchEntry("replace", ap, Some(newTree._text))))
    }
}

private func diffFragment(old: FragmentNode, newTree: FragmentNode, basePath: String, patches: ArrayList<GranularPatch>): Unit {
    diffChildren(old._children, newTree._children, basePath, patches)
}

private func diffChildren(oldChildren: Array<Component>, newChildren: Array<Component>, basePath: String, patches: ArrayList<GranularPatch>): Unit {
    let maxLen = if (oldChildren.size > newChildren.size) { oldChildren.size } else { newChildren.size }
    for (i in 0..maxLen) {
        let cp = if (basePath == "") { "/children/${i}" } else { "${basePath}/children/${i}" }
        if (i >= oldChildren.size) {
            patches.add(GranularPatch.SubtreePatch(TreePatchEntry("add", cp, Some(newChildren[i]))))
        } else if (i >= newChildren.size) {
            patches.add(GranularPatch.SubtreePatch(TreePatchEntry("remove", cp, None)))
        } else {
            let sub = diffTree(oldChildren[i], newChildren[i], cp)
            for (p in sub) { patches.add(p) }
        }
    }
}
