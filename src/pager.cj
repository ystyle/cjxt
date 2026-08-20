package cjxt

import std.collection.ArrayList

// ============ Pagination 纯逻辑（对齐 Element Plus pager.vue 算法） ============

// 分页器中间页计算结果
public struct PagerInfo {
    public let showPrevMore: Bool
    public let showNextMore: Bool
    public let pages: Array<Int64>

    public init(showPrevMore: Bool, showNextMore: Bool, pages: Array<Int64>) {
        this.showPrevMore = showPrevMore
        this.showNextMore = showNextMore
        this.pages = pages
    }
}

// 总条数/每页条数 → 总页数（向上取整，非法输入按 1 处理）
public func computePageCount(total: Int64, pageSize: Int64): Int64 {
    if (total <= 0 || pageSize <= 0) { return 1 }
    (total + pageSize - 1) / pageSize
}

// 页码夹取到 [1, pageCount]
public func clampPage(page: Int64, pageCount: Int64): Int64 {
    if (page < 1) { 1 } else if (page > pageCount) { pageCount } else { page }
}

/**
 * 计算中间页码列表（不含首尾页，首尾页由渲染层单独输出）与省略号状态。
 * 算法与 Element Plus pager.vue 的 pagers computed 一致：
 * - pagerCount（默认 7）为分页器内页数上限，超过时折叠为省略号
 * - halfPagerCount = (pagerCount - 1) / 2
 * - showPrevMore = pageCount > pagerCount && currentPage > pagerCount - halfPagerCount
 * - showNextMore = pageCount > pagerCount && currentPage < pageCount - halfPagerCount
 */
public func computePager(currentPage: Int64, pageCount: Int64, pagerCount: Int64): PagerInfo {
    let halfPagerCount = (pagerCount - 1) / 2
    var showPrevMore = false
    var showNextMore = false
    if (pageCount > pagerCount) {
        if (currentPage > pagerCount - halfPagerCount) { showPrevMore = true }
        if (currentPage < pageCount - halfPagerCount) { showNextMore = true }
    }
    let array = ArrayList<Int64>()
    if (showPrevMore && !showNextMore) {
        let startPage = pageCount - (pagerCount - 2)
        var i = startPage
        while (i < pageCount) { array.add(i); i += 1 }
    } else if (!showPrevMore && showNextMore) {
        var i: Int64 = 2
        while (i < pagerCount) { array.add(i); i += 1 }
    } else if (showPrevMore && showNextMore) {
        let offset = pagerCount / 2 - 1
        var i = currentPage - offset
        while (i <= currentPage + offset) { array.add(i); i += 1 }
    } else {
        var i: Int64 = 2
        while (i < pageCount) { array.add(i); i += 1 }
    }
    PagerInfo(showPrevMore, showNextMore, array.toArray())
}
