# Select Enhancement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enhance Select with multiple select, clearable, filterable, and option grouping.

**Architecture:** Extend Select class with new fields/methods; add SelectOptionGroup; modify render() and buildDropdown() for multi-mode tag display and filtering.

**Tech Stack:** Cangjie, cjxt, Element Plus SCSS

---

### Task 0: Pre-check — Icon availability

**Files:**
- Read: `src/components/Icons.cj` (confirm `close`, `circle-close` exist)
- Read: `public/scss/element-plus/element-plus.scss` (confirm `tag.scss` is imported)
- Read: `public/scss/element-plus/tag.scss` (check if styles exist)

**Expected:** `close` icon exists, `tag.scss` is in element-plus.scss.

---

### Task 1: Add SelectOptionGroup class

**Files:**
- Modify: `src/components/Select.cj`

**Step 1: Add class to end of file**

```cj
public class SelectOptionGroup <: Component {
    var _label: String
    var _children: Array<IComponent>

    public init(children: Array<IComponent>, label: String) {
        this._children = children
        this._label = label
    }

    public func render(): IComponent {
        let title = VNode("span", [text(this._label)], attrs: Some(HashMap<String, String>([("class", "el-select-dropdown__group-title")])))
        VNode("li", [title], attrs: Some(HashMap<String, String>([("class", "el-select-dropdown__group")])))
    }

    func getChildren(): Array<IComponent> { this._children }
}
```

**Step 2:** Build: `cjpm build` → success

---

### Task 2: Extend Select with new fields and methods

**Files:**
- Modify: `src/components/Select.cj`

**Step 1: Add fields after existing fields**

```cj
    var _multiple: Bool = false
    var _clearable: Bool = false
    var _filterable: Bool = false
    var _multiSignal: Option<Signal<ArrayList<String>>> = None
    var _filterText: Signal<String>
```

In init(), after `this._open = ...`, add:
```cj
    this._filterText = Signal<String>("")
```

**Step 2: Add chain methods**

```cj
    public func multiple(): Select { this._multiple = true; this }
    public func clearable(): Select { this._clearable = true; this }
    public func filterable(): Select { this._filterable = true; this }
    public func bindMulti(signal: Signal<ArrayList<String>>): Select { this._multiSignal = Some(signal); this }
```

**Step 3:** Build: `cjpm build` → success

---

### Task 3: Modify render() for multiple mode

**Files:**
- Modify: `src/components/Select.cj`

**Step 1: Add helper methods**

```cj
    func buildTags(selected: ArrayList<String>): Array<IComponent> {
        let items = ArrayList<IComponent>()
        for (val in selected) {
            let label = this.findLabel(val)
            let content = VNode("span", [text(label)], attrs: Some(HashMap<String, String>([("class", "el-tag__content")])))
            let tag = VNode("span", [content], attrs: Some(HashMap<String, String>([("class", "el-tag el-tag--info")])))
            let v = val
            match (this._multiSignal) {
                case Some(s) => tag.onClick({ ctx =>
                    let list = s.get()
                    let idx = this.findIndex(list, v)
                    if (idx >= 0) { list.remove(idx..idx + 1) }
                    s.set(list)
                    PatchResult.ReRender
                })
                case None => ()
            }
            items.add(tag)
        }
        items.toArray()
    }

    func findIndex(list: ArrayList<String>, value: String): Int64 {
        var i = 0
        for (v in list) { if (v == value) { return i }; i = i + 1 }
        -1
    }
```

**Step 2: Update render() selection display**

Replace the current selection span rendering with conditional logic:
- If `_multiple` and has selected values: buildTags() → render inside `el-select__selection`
- If `_multiple` and empty: show placeholder
- If not `_multiple`: existing single display

**Step 3: Update buildDropdown() for multi toggle**

In option click handler:
- Single mode (existing): `s.set(v); o.set(false)`
- Multi mode: `let list = multiSignal.get(); toggle value in list; multiSignal.set(list)` — do NOT close dropdown

**Step 4:** Build: `cjpm build` → success

---

### Task 4: Add clearable icon

**Files:**
- Modify: `src/components/Select.cj`

**Step 1: Add clear icon in suffix area**

When `_clearable` and has value (single: string not empty; multi: ArrayList not empty), render clear icon before arrow suffix:

```cj
if (this._clearable && hasValue) {
    let clearEl = Icon("circle-close").render()
    clearEl.onClick({ ctx =>
        match (this._signal) { case Some(s) => s.set(""); case None => () }
        match (this._multiSignal) { case Some(s) => s.set(ArrayList<String>()); case None => () }
        PatchResult.ReRender
    })
}
```

**Step 2:** Build: `cjpm build` → success

---

### Task 5: Add filterable input

**Files:**
- Modify: `src/components/Select.cj`

**Step 1: Add filter input in dropdown header**

In buildDropdown(), before options list:
```cj
if (this._filterable) {
    let inputAttrs = HashMap<String, String>([("class", "el-select__input"), ("type", "text"), ("placeholder", "搜索")])
    let inputEl = VNode("input", [], attrs: Some(inputAttrs))
    inputEl = inputEl.bind(this._filterText)
    ...
}
```

**Step 2: Filter options in buildDropdown()**

When building items, check `_filterText.get()`:
```cj
let filter = if (this._filterable) { this._filterText.get() } else { "" }
for (c in this._children) {
    match (c) {
        case opt: SelectOption => {
            if (filter == "" || this.optionMatches(opt, filter)) {
                items.add(opt.renderItem(...))
            }
        }
        case g: SelectOptionGroup => { ... }
        case _ => items.add(c)
    }
}
```

Add optionMatches helper:
```cj
func optionMatches(opt: SelectOption, filter: String): Bool {
    let label = this.extractLabel(opt)
    label.toLower().contains(filter.toLower())
}
```

**Step 3:** Build: `cjpm build` → success

---

### Task 6: Update showcase demo

**Files:**
- Modify: `examples/src/showcase.cj`

**Step 1: Update demoSelect()**

Add sections:
- Basic single (existing)
- Disabled (existing)
- **Multiple** with tags
- **Clearable** single
- **Filterable** single
- **Option Group** with grouped options

Example new sections:
```cj
div([text("多选")], style: "font-size:12px;color:#909399;margin-top:8px"),
Select([
    SelectOption([text("选项A")], "a"),
    SelectOption([text("选项B")], "b"),
    SelectOption([text("选项C")], "c"),
]).multiple().placeholder("请选择多个").bindMulti(this.state.multiSelectValue),

div([text("可清除")], style: "font-size:12px;color:#909399;margin-top:8px"),
Select([
    SelectOption([text("选项A")], "a"),
    SelectOption([text("选项B")], "b"),
]).clearable().placeholder("可清除").bind(this.state.selectValue),

div([text("可搜索")], style: "font-size:12px;color:#909399;margin-top:8px"),
Select([
    SelectOption([text("选项A"), text("(描述)")], "a"),
    SelectOption([text("选项B")], "b"),
    SelectOption([text("选项C")], "c"),
]).filterable().placeholder("输入搜索").bind(this.state.selectValue),

div([text("选项分组")], style: "font-size:12px;color:#909399;margin-top:8px"),
Select([
    SelectOptionGroup([SelectOption([text("选项A")], "a")], "分组1"),
    SelectOptionGroup([SelectOption([text("选项B")], "b"), SelectOption([text("选项C")], "c")], "分组2"),
]).placeholder("请选择分组").bind(this.state.selectValue),
```

**Step 2: Add state field**

In ShowcaseState, add:
```cj
var multiSelectValue = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
```

---

### Task 7: CSS — ensure tag and group styles exist

**Files:**
- Modify: `public/scss/element-plus/element-plus.scss`

**Step 1: Add tag.scss if missing**

Check element-plus.scss for `@use 'tag.scss'`. If missing, add it.

**Step 2: Add group fallback styles if EP doesn't output them**

Check bundle.css for `.el-select-dropdown__group`. If missing, add:
```scss
.el-select-dropdown__group {
  .el-select-dropdown__group-title {
    padding: 8px 20px;
    font-size: 12px;
    color: #909399;
    line-height: 1.5;
  }
}
```

---

### Task 8: Rebuild and browser verify

**Steps:**
1. `cjpm build` (main lib)
2. `cd examples && cjpm build` (examples)
3. `cd .. && ./scripts/build-css.sh` (EP styles)
4. Start server: `cd examples && ./target/release/bin/main`
5. Open http://localhost:8080/showcase
6. Click Select menu
7. Verify: basic select works (regression)
8. Verify: multiple select toggles options, shows tags
9. Verify: clearable shows clear icon, clicking clears value
10. Verify: filterable shows input, typing filters options
11. Verify: option group renders group title
