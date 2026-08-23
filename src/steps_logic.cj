package cjxt

// ============ Steps 状态推导（纯逻辑，供 Steps 组件与单测共用） ============

// 推导步骤状态：返回 EP 的 currentStatus（success/process/wait/error）。
// status 非空（强制状态）优先；否则按 index vs active（1 起）推导。
public func stepsStatus(status: String, idx: Int64, active: Int64, processStatus: String, finishStatus: String): String {
    if (status != "") {
        return mapStepStatus(status)
    }
    if (idx < active - 1) {
        mapStepStatus(finishStatus)
    } else if (idx == active - 1) {
        mapStepStatus(processStatus)
    } else {
        "wait"
    }
}

// 内部状态名 → EP currentStatus
public func mapStepStatus(s: String): String {
    match (s) {
        case "finish" => "success"
        case "process" => "process"
        case "wait" => "wait"
        case "error" => "error"
        case _ => s
    }
}

// ============ 步骤布局（对齐 EP item.vue 的 style 计算） ============
//
// EP 无 space 时：每步 flex-basis = 100/(n-1)%（末步由 is-flex 类覆盖为 auto），
// 末步 max-width = 100/n%；垂直方向不设置布局样式。
// 参考：element-plus steps/src/item.vue style computed。
public func stepFlexStyle(total: Int64, isLast: Bool, isVertical: Bool): String {
    if (isVertical) {
        return ""
    }
    if (total <= 1) {
        if (isLast) {
            return "flex-basis: 100%; max-width: 100%"
        }
        return "flex-basis: 100%"
    }
    let basis = 100.0 / Float64(total - 1)
    var style = "flex-basis: ${basis}%"
    if (isLast) {
        let maxW = 100.0 / Float64(total)
        style = "${style}; max-width: ${maxW}%"
    }
    style
}
