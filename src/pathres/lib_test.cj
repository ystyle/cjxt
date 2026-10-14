// 宏期"当前包定位"逻辑的单元测试。
//
// 这组测试守的是同一个契约：**资源的定位基准是"正在编译的包"，不是调用方的 cwd**。
// 起因是 cjpm workspace 下逐成员编译时 cwd 常常是 workspace 根，按相对路径写死的
// 资源会找不到（表现为 `@importCSS("style.css")` 报 file not found）。
package cjxt.pathres

import std.fs.{Directory, File, Path, remove}
import std.unittest.*
import std.unittest.testmacro.*

@Test
class PathResolveTest {

    // `-p <dir>` / `--package <dir>` / `-p=<dir>` / `--package=<dir>` 四种写法都要认
    @TestCase
    func testStartDirFromArgsForms(): Unit {
        @Expect(startDirFromArgs(["cjc", "-p", "/a/b/src"]) ?? "", "/a/b/src")
        @Expect(startDirFromArgs(["cjc", "--package", "/a/b/src"]) ?? "", "/a/b/src")
        @Expect(startDirFromArgs(["cjc", "-p=/a/b/src", "-o=x"]) ?? "", "/a/b/src")
        @Expect(startDirFromArgs(["cjc", "--package=/a/b/src"]) ?? "", "/a/b/src")
    }

    // 没有 -p 时以源码文件为输入：取该文件所在目录
    @TestCase
    func testStartDirFromBareSourceFile(): Unit {
        @Expect(startDirFromArgs(["cjc", "/proj/build.cj", "-o", "x"]) ?? "", "/proj")
    }

    // 取不到任何线索返回 None（调用方据此退回 cwd）
    @TestCase
    func testStartDirWithoutClues(): Unit {
        @Expect(startDirFromArgs(["cjc", "-o", "x"]).isNone(), true)
    }

    // 向上找最近的 cjpm.toml：子包目录也要能找到项目根
    @TestCase
    func testFindProjectDirWalksUpFromSubpackage(): Unit {
        let root = "/tmp/cjxt-pathres-test-${nowMark()}"
        let sub = Path(root).join("src").join("sub").toString()
        Directory.create(sub, recursive: true)
        try {
            File.writeTo(Path(root).join("cjpm.toml").toString(), "x".toArray())
            @Expect(findProjectDir(sub) ?? "", root)
            @Expect(findProjectDir(Path(root).join("src").toString()) ?? "", root)
        } finally {
            remove(root, recursive: true)
        }
    }

    // 没有清单时返回 None，而不是无限向上或返回错误目录
    @TestCase
    func testFindProjectDirWithoutManifest(): Unit {
        let root = "/tmp/cjxt-pathres-nomanifest-${nowMark()}"
        Directory.create(root, recursive: true)
        try {
            @Expect(findProjectDir(root).isNone(), true)
        } finally {
            remove(root, recursive: true)
        }
    }

    // 候选顺序：原样 → src/ → public/css/ → public/sass/
    @TestCase
    func testResourceCandidatesOrder(): Unit {
        let c = resourceCandidates("style.css")
        @Expect(c.size, 4)
        @Expect(c[0], "style.css")
        @Expect(c[1], "src/style.css")
        @Expect(c[2], "public/css/style.css")
        @Expect(c[3], "public/sass/style.css")
    }

    // 都找不到时返回空串（调用方据此报错，不做静默兜底）
    @TestCase
    func testResolveResourceMissingReturnsEmpty(): Unit {
        @Expect(resolveResource("definitely-not-here-${nowMark()}.css"), "")
    }
}

var counter: Int64 = 0

// 用进程内单调计数即可：测试只要求临时目录名唯一
func nowMark(): Int64 {
    counter += 1
    counter
}
