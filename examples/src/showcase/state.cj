// ShowcaseState：演示站共享状态（package examples.showcase）
// 字段对主包 ShowcasePage 只暴露 selected（侧栏选中）；其余字段由本包的
// demo 函数（同包）package-private 访问。

package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.{ArrayList, HashMap}

// 响应式演示辅助：顶层函数让 lambda 只捕获参数（构造函数里不能创建捕获 this 的闭包）
func makeReactiveDouble(s: Signal<Int64>): Computed<Int64> {
    Computed<Int64>({ => s.get() * 2 })
}
func makeReactiveEff(s: Signal<Int64>, out: Signal<Int64>): Effect {
    Effect({ => out.set(s.get()) })
}

// Table 泛型演示行类型
public struct TableRow {
    public let date: String
    public let name: String
    public let state: String
    public let city: String
    public let address: String
    public let price: String

    public init(date: String, name: String, state: String, city: String, address: String, price: String) {
        this.date = date
        this.name = name
        this.state = state
        this.city = city
        this.address = address
        this.price = price
    }
}

public class ShowcaseState <: AppState {
    public var selected = Signal<String>("Button")
    var radioValue = Signal<String>("a")
    var checkboxValue = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
    var rateValue = Signal<Float64>(3.0)
    var inputArea = Signal<String>("")
    var checkAgree = Signal<Bool>(false)
    var radioStandalone = Signal<String>("")
    var switchValue = Signal<Bool>(true)
    var inputNumberValue = Signal<Int64>(3)
    var selectValue = Signal<String>("")
    var clearableValue = Signal<String>("")
    var filterableValue = Signal<String>("")
    var groupValue = Signal<String>("")
    var multiSelectValue = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
    var sliderValue = Signal<Int64>(30)
    var tagVisible = Signal<Bool>(true)
    var paginationPage = Signal<Int64>(1)
    var paginationSize = Signal<Int64>(10)
    var dateValue = Signal<String>("2026-08-05")
    var rangeStart = Signal<String>("2026-08-01")
    var rangeEnd = Signal<String>("2026-08-15")
    var messageItems = Signal<ArrayList<MessageItem>>(ArrayList<MessageItem>())
    var notificationItems = Signal<ArrayList<NotificationItem>>(ArrayList<NotificationItem>())
    var loadingVisible = Signal<Bool>(false)
    var activeTab = Signal<String>("tab1")
    var chatMessages = Signal<ArrayList<String>>(ArrayList<String>())
    var chatCounter = Signal<Int64>(0)
    var reactiveCount = Signal<Int64>(0)
    var reactiveEffCount = Signal<Int64>(0)
    var reactiveDouble: Computed<Int64>
    var reactiveEff: Effect
    var virtualItems: Signal<ArrayList<Int64>>
    var virtualScrollTop = Signal<Int64>(0)
    var domTxResult = Signal<String>("未查询")
    var stepsActive = Signal<Int64>(1)
    var dropdownResult = Signal<String>("未选择")
    var popconfirmResult = Signal<String>("未操作")
    var messageBoxAlertVisible = Signal<Bool>(false)
    var messageBoxConfirmVisible = Signal<Bool>(false)
    var messageBoxPromptVisible = Signal<Bool>(false)
    var messageBoxPromptValue = Signal<String>("")
    var messageBoxResult = Signal<String>("未操作")
    var treeCurrent = Signal<String>("")
    var treeNodeLabel = Signal<String>("未选节点")
    var treeExpanded = Signal<HashMap<String, Bool>>(HashMap<String, Bool>())
    var cascaderSelected = Signal<ArrayList<String>>(ArrayList<String>())
    var cascaderText = Signal<String>("未选择")
    var uploadFiles = Signal<ArrayList<UploadFile>>(ArrayList<UploadFile>())
    var calendarValue = Signal<String>("2026-08-15")
    var calendarView = Signal<String>("2026-08-01")
    var timeValue = Signal<String>("09:30:45")
    var formUsername = Signal<String>("")
    var formPassword = Signal<String>("")
    var formUserError = Signal<String>("")
    var formPwdError = Signal<String>("")
    var formEmailError = Signal<String>("")
    var formEmail = Signal<String>("")
    var formError = Signal<String>("")
    var formSwitch = Signal<Bool>(true)
    var dialogVisible = Signal<Bool>(false)
    var dialogNestedVisible = Signal<Bool>(false)
    var drawerVisible = Signal<Bool>(false)
    var drawerDirection = Signal<String>("rtl")
    var formLayout = Signal<String>("")
    var tableData = Signal<ArrayList<TableRow>>(ArrayList<TableRow>())
    var tableSortColumn = Signal<String>("")
    var tableSortOrder = Signal<SortOrder>(SortOrder.None)
    var tableSelectedRows = Signal<ArrayList<TableRow>>(ArrayList<TableRow>())
    var tableCurrentRow: Signal<Option<TableRow>>

    // ── 第 1-5 批新增组件（2026-10-23）──────────────────────────
    var segmentedValue = Signal<String>("日")
    var segmentedValue2 = Signal<String>("a")
    var segmentedValue3 = Signal<String>("上")
    var radioButtonValue = Signal<String>("bj")
    var radioButtonValue2 = Signal<String>("on")
    var radioButtonValue3 = Signal<String>("l")
    var radioButtonValue4 = Signal<String>("s")
    var checkboxButtonValue = Signal<ArrayList<String>>(ArrayList<String>(["read"]))
    var checkboxButtonValue2 = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
    var otpValue = Signal<String>("")
    var otpValue2 = Signal<String>("")
    var otpValue3 = Signal<String>("")
    var otpValue4 = Signal<String>("")
    var tagValues = Signal<ArrayList<String>>(ArrayList<String>(["Cangjie", "cjxt"]))
    var tagValues2 = Signal<ArrayList<String>>(ArrayList<String>())
    var tagValues3 = Signal<ArrayList<String>>(ArrayList<String>(["只读标签"]))
    var carouselIndex = Signal<Int64>(0)
    var transferValues = Signal<ArrayList<String>>(ArrayList<String>(["2"]))
    var colorValue = Signal<String>("#409eff")
    var colorValue2 = Signal<String>("#67c23a")
    var colorValue3 = Signal<String>("#e6a23c")
    var colorValue4 = Signal<String>("#f56c6c")
    var tourVisible = Signal<Bool>(false)
    var pageHeaderMsg = "未点击"

    public func segmentedIndex(): Int64 {
        match (this.segmentedValue.get()) {
            case "日" => 1
            case "周" => 2
            case "月" => 3
            case _ => 0
        }
    }

    public func tagSummary(): String {
        let list = this.tagValues.get()
        if (list.size == 0) { return "（空）" }
        var out = ""
        for (i in 0..list.size) {
            if (i > 0) { out = "${out}、" }
            out = "${out}${list[i]}"
        }
        out
    }

    public init() {
        this.reactiveDouble = makeReactiveDouble(this.reactiveCount)
        this.reactiveEff = makeReactiveEff(this.reactiveCount, this.reactiveEffCount)
        let vitems = ArrayList<Int64>()
        for (i in 1..=10000) { vitems.add(i) }
        this.virtualItems = Signal<ArrayList<Int64>>(vitems)
        let noneRow: Option<TableRow> = None
        this.tableCurrentRow = Signal<Option<TableRow>>(noneRow)
    }
}
