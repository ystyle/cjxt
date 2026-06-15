package cjxt

import std.collection.*

private func typesEqual(a: ComponentType, b: ComponentType): Bool {
    match (a) {
        case ComponentType.Div => match (b) { case ComponentType.Div => true; case _ => false }
        case ComponentType.Span => match (b) { case ComponentType.Span => true; case _ => false }
        case ComponentType.Button => match (b) { case ComponentType.Button => true; case _ => false }
        case ComponentType.Input => match (b) { case ComponentType.Input => true; case _ => false }
        case ComponentType.Form => match (b) { case ComponentType.Form => true; case _ => false }
        case ComponentType.Table => match (b) { case ComponentType.Table => true; case _ => false }
        case ComponentType.Text => match (b) { case ComponentType.Text => true; case _ => false }
        case ComponentType.Image => match (b) { case ComponentType.Image => true; case _ => false }
        case ComponentType.H1 => match (b) { case ComponentType.H1 => true; case _ => false }
        case ComponentType.H2 => match (b) { case ComponentType.H2 => true; case _ => false }
        case ComponentType.H3 => match (b) { case ComponentType.H3 => true; case _ => false }
        case ComponentType.P => match (b) { case ComponentType.P => true; case _ => false }
        case ComponentType.Select => match (b) { case ComponentType.Select => true; case _ => false }
        case ComponentType.Textarea => match (b) { case ComponentType.Textarea => true; case _ => false }
        case ComponentType.A => match (b) { case ComponentType.A => true; case _ => false }
        case ComponentType.Ul => match (b) { case ComponentType.Ul => true; case _ => false }
        case ComponentType.Li => match (b) { case ComponentType.Li => true; case _ => false }
    }
}

private func optionsEqual(a: Option<String>, b: Option<String>): Bool {
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

private func optionGetOr(o: Option<String>, defaultVal: String): String {
    match (o) {
        case Some(v) => v
        case None => defaultVal
    }
}

public func diffTree(old: ComponentNode, newTree: ComponentNode, basePath: String): ArrayList<PatchEntry> {
    let patches = ArrayList<PatchEntry>()

    if (!typesEqual(old.typ, newTree.typ) || !optionsEqual(old.key, newTree.key)) {
        patches.add(PatchEntry("replace", basePath, Some(""), None))
        return patches
    }

    let allAttrKeys = mergeKeys(old.attrs, newTree.attrs)
    for (key in allAttrKeys) {
        let oldVal = old.attrs.get(key)
        let newVal = newTree.attrs.get(key)
        if (oldVal != newVal) {
            let attrPath = if (basePath == "") { "/attrs/${key}" } else { "${basePath}/attrs/${key}" }
            if (newVal == None) {
                patches.add(PatchEntry("remove", attrPath, None, None))
            } else {
                patches.add(PatchEntry("replace", attrPath, Some(optionGetOr(newVal, "")), None))
            }
        }
    }

    let allActionKeys = mergeKeys(old.actions, newTree.actions)
    for (key in allActionKeys) {
        let oldAct = old.actions.get(key)
        let newAct = newTree.actions.get(key)
        if (oldAct != newAct) {
            let actPath = if (basePath == "") { "/actions/${key}" } else { "${basePath}/actions/${key}" }
            if (newAct == None) {
                patches.add(PatchEntry("remove", actPath, None, None))
            } else {
                patches.add(PatchEntry("replace", actPath, Some(optionGetOr(newAct, "")), None))
            }
        }
    }

    let maxLen = if (old.children.size > newTree.children.size) { old.children.size } else { newTree.children.size }
    for (i in 0..maxLen) {
        let childPath = if (basePath == "") { "/children/${i}" } else { "${basePath}/children/${i}" }
        if (i >= old.children.size) {
            patches.add(PatchEntry("add", childPath, Some(""), None))
        } else if (i >= newTree.children.size) {
            patches.add(PatchEntry("remove", childPath, None, None))
        } else {
            let sub = diffTree(old.children[i], newTree.children[i], childPath)
            for (p in sub) {
                patches.add(p)
            }
        }
    }

    patches
}

private func mergeKeys(a: HashMap<String, String>, b: HashMap<String, String>): ArrayList<String> {
    let keys = ArrayList<String>()
    for (k in a.keys()) {
        keys.add(k)
    }
    for (k in b.keys()) {
        if (!keys.contains(k)) {
            keys.add(k)
        }
    }
    keys
}
