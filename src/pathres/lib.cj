// 宏期的"当前包定位"逻辑。
//
// 独立成普通包（而非直接写在宏包里）是为了可单元测试：宏包（`macro package`）里的
// `@Test` 不会被登记，`cjpm test` 收集不到用例。
//
// 为什么不能只用 cwd：宏在 cjc 进程内展开，cwd 是**调用方的工作目录**；在 cjpm
// workspace 下逐成员编译时，cwd 往往是 workspace 根而不是成员目录，于是按相对路径
// 写死的资源（如 `public/css/style.css`）会找不到。编译器 argv 里的 `-p` 才指向
// **当前正在编译的包**，据此向上找 `cjpm.toml` 才能定位到该包所在的项目目录。
package cjxt.pathres

import std.collection.ArrayList
import std.env.{getCommandLine, getVariable}
import std.fs.{Path, exists}

/// 从编译器命令行取"正在编译的包"的源码目录。
///
/// 覆盖 `-p <dir>` / `--package <dir>` / `-p=<dir>` / `--package=<dir>` 四种写法；
/// 没有 `-p` 时（cjc 直接以源码文件为输入，如编译 `build.cj`）退回该文件所在目录。
public func startDirFromArgs(args: Array<String>): ?String {
    var i = 0
    while (i < args.size) {
        let a = args[i]
        if (a == "-p" || a == "--package") {
            if (i + 1 < args.size) { return args[i + 1] }
        } else if (a.startsWith("-p=") || a.startsWith("--package=")) {
            if (let Some(eq) <- a.indexOf("=")) {
                return a[eq + 1..a.size]
            }
        }
        i++
    }
    for (a in args) {
        if (a.endsWith(".cj")) {
            return Path(a).parent.toString()
        }
    }
    None
}

/// 从给定目录向上找最近的 `cjpm.toml` 所在目录。
///
/// 子包编译时 `-p` 指向 `<proj>/src/sub`，只取父目录会落在 `<proj>/src`（那里没有
/// 清单），因此必须逐级向上找。
public func findProjectDir(start: String): ?String {
    var cur = Path(start)
    var depth = 0
    while (depth < 16) {
        if (exists(cur.join("cjpm.toml").toString())) {
            return cur.toString()
        }
        let up = cur.parent
        if (up.toString() == cur.toString()) { break }
        cur = up
        depth++
    }
    None
}

/// 当前包所在的项目目录：优先用编译器给的信息，取不到再退回调用方工作目录。
public func resolveProjectDir(): ?String {
    if (let Some(start) <- startDirFromArgs(getCommandLine())) {
        if (let Some(proj) <- findProjectDir(start)) {
            return proj
        }
    }
    let pwd = match (getVariable("PWD")) {
        case Some(v) => v
        case None => "."
    }
    findProjectDir(pwd)
}

/// 资源查找的候选路径（相对项目目录）。
///
/// 返回相对路径列表而不是绝对路径：调用方自行决定"取第一个存在的"，这样
/// 各类调用点（CSS / 其它资源）能复用同一套顺序。
public func resourceCandidates(relative: String): Array<String> {
    let out = ArrayList<String>()
    out.add(relative)
    out.add("src/${relative}")
    out.add("public/css/${relative}")
    out.add("public/sass/${relative}")
    out.toArray()
}

/// 解析资源路径：先按项目目录拼，再退回 cwd 相对（兼容单包工程与旧用法）。
///
/// 返回空串表示都没找到；调用方据此报错，**不做静默兜底**。
public func resolveResource(relative: String): String {
    let bases = ArrayList<String>()
    match (resolveProjectDir()) {
        case Some(proj) => bases.add(proj)
        case None => ()
    }
    bases.add(".")
    for (base in bases) {
        for (cand in resourceCandidates(relative)) {
            let full = if (base == ".") { cand } else { Path(base).join(cand).toString() }
            if (exists(full)) { return full }
        }
    }
    ""
}
