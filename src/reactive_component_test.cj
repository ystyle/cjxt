package cjxt

import std.unittest.*
import std.unittest.testmacro.*

// 测试组件：渲染时读取一个 Computed（派生值）
class ComputedPage <: Component {
    let derived: Computed<Int64>
    public init(derived: Computed<Int64>) {
        this.derived = derived
    }
    public func render(): IComponent {
        div([text("sum=${this.derived.get()}")])
    }
}

// 测试组件：渲染时读取一个 Effect 维护的派生信号
class EffectPage <: Component {
    let out: Signal<Int64>
    public init(out: Signal<Int64>) {
        this.out = out
    }
    public func render(): IComponent {
        div([text("v=${this.out.get()}")])
    }
}

@Test
public class ReactiveComponentTest {
    @TestCase
    public func testComponentDirtyThroughComputed(): Unit {
        let a = Signal<Int64>(2)
        let b = Signal<Int64>(3)
        let sum = Computed<Int64>({ => a.get() + b.get() })
        let comp = ComputedPage(sum)
        comp.renderWithScope("")
        // 渲染完成：订阅已建立，未标脏
        @Expect(comp.isDirty(), false)
        @Expect(sum.get(), 5)
        // 依赖信号变化 → computed 失效 → 组件标脏（脏追踪穿透 computed）
        a.set(10)
        @Expect(comp.isDirty(), true)
        @Expect(sum.get(), 13)
        RenderContext.clearDirty()
    }

    @TestCase
    public func testComponentDirtyThroughChainedComputed(): Unit {
        let a = Signal<Int64>(1)
        let double = Computed<Int64>({ => a.get() * 2 })
        let plus1 = Computed<Int64>({ => double.get() + 1 })
        let comp = ComputedPage(plus1)
        comp.renderWithScope("")
        @Expect(comp.isDirty(), false)
        a.set(5)
        // 链式：a → double → plus1 → 组件
        @Expect(comp.isDirty(), true)
        @Expect(plus1.get(), 11)
        RenderContext.clearDirty()
    }

    @TestCase
    public func testEffectDrivesComponentRerender(): Unit {
        let a = Signal<Int64>(1)
        let out = Signal<Int64>(0)
        let eff = Effect({ => out.set(a.get() * 2) })
        let comp = EffectPage(out)
        comp.renderWithScope("")
        @Expect(comp.isDirty(), false)
        a.set(7)
        // effect 重跑 → out 更新 → 组件标脏
        @Expect(comp.isDirty(), true)
        @Expect(out.get(), 14)
        RenderContext.clearDirty()
    }

    @TestCase
    public func testComputedDirtyIndependentOfOtherComponent(): Unit {
        let a = Signal<Int64>(1)
        let sum = Computed<Int64>({ => a.get() + 1 })
        let c1 = ComputedPage(sum)
        let c2 = ComputedPage(sum)
        c1.renderWithScope("p/0")
        c2.renderWithScope("p/1")
        @Expect(c1.isDirty(), false)
        @Expect(c2.isDirty(), false)
        a.set(9)
        // 两个组件都订阅了同一 computed → 都标脏
        @Expect(c1.isDirty(), true)
        @Expect(c2.isDirty(), true)
        RenderContext.clearDirty()
    }
}

@Test
public class ReadableTest {
    @TestCase
    public func testReadableAcceptsSignalAndComputed(): Unit {
        let s = Signal<String>("hi")
        let c = Computed<String>({ => "${s.get()}!" })
        let r1: Readable<String> = s
        let r2: Readable<String> = c
        @Expect(r1.get(), "hi")
        @Expect(r2.get(), "hi!")
    }

}
