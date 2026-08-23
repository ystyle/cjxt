package cjxt

import std.collection.ArrayList

// ============ Upload 纯逻辑（文件列表增删） ============

public class UploadFile {
    public let name: String
    public let url: String
    public let size: Int64

    public init(name: String, url: String, size: Int64) {
        this.name = name
        this.url = url
        this.size = size
    }
}

// 追加文件（按 url 去重）
public func uploadAppend(files: ArrayList<UploadFile>, f: UploadFile): ArrayList<UploadFile> {
    let next = ArrayList<UploadFile>()
    for (x in files) { next.add(x) }
    // 去重
    for (x in files) {
        if (x.url == f.url) { return next }
    }
    next.add(f)
    next
}

// 删除指定 url 的文件
public func uploadRemove(files: ArrayList<UploadFile>, url: String): ArrayList<UploadFile> {
    let next = ArrayList<UploadFile>()
    for (x in files) {
        if (x.url != url) { next.add(x) }
    }
    next
}
