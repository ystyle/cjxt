package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}
import std.convert.*

// ============ Upload 上传（对齐 Element Plus，服务端驱动 + 客户端 XHR） ============
//
// 服务端：App.serveUpload("/_cjxt/uploads", "uploads") —— POST multipart 存文件，返回 {name,url,size}
// 客户端：隐藏 file input（data-upload-input + data-upload）change 后 XHR 上传；成功后按
//   data-action-uploaded（稳定 handler id）dispatch action，服务端 handler 把文件加入 files 信号。
// 组件：Upload(url).files(Signal<ArrayList<UploadFile>>).onUploaded(cb)
//   files 外置（父重渲染 new 新实例丢内部信号——Table 经验）。

public class Upload <: Component {
    var _url: String = ""
    var _files: Signal<ArrayList<UploadFile>> = Signal<ArrayList<UploadFile>>(ArrayList<UploadFile>())
    var _onUploaded: Option<(UploadFile) -> Unit> = None

    public func url(v: String): Upload {
        this._url = v
        this
    }

    public func files(v: Signal<ArrayList<UploadFile>>): Upload {
        this._files = v
        this
    }

    public func onUploaded(h: (UploadFile) -> Unit): Upload {
        this._onUploaded = Some(h)
        this
    }

    public func render(): IComponent {
        // 上传成功 handler：客户端 dispatch action 后把文件加入列表
        let uploadH: ActionHandler = { ctx =>
            let name = match (ctx.params.get("name")) { case Some(v) => v case None => "" }
            let url = match (ctx.params.get("url")) { case Some(v) => v case None => "" }
            let size = match (ctx.params.get("size")) { case Some(v) => Int64.parse(v, radix: 10) case None => 0 }
            let file = UploadFile(name, url, size)
            this._files.set(uploadAppend(this._files.get(), file))
            match (this._onUploaded) {
                case Some(cb) => cb(file)
                case None => ()
            }
            PatchResult.ReRender
        }
        // 隐藏 file input：客户端 XHR 上传后读 data-action-uploaded dispatch
        let input = VNode("input", [], attrs: Some(HashMap<String, String>([("type", "file"), ("style", "display:none"), ("data-upload-input", "1"), ("data-upload", this._url)]))).on("uploaded", uploadH)
        // 触发区（客户端拦截 data-upload-trigger 点击 → 点 file input）
        let trigger = VNode("div", [
            VNode("div", [text("点击上传或拖拽到此处")], attrs: Some(HashMap<String, String>([("class", "el-upload__text")]))),
        ], attrs: Some(HashMap<String, String>([("class", "el-upload-dragger"), ("data-upload-trigger", "1")])))
        // 文件列表
        let list = this.buildList()
        VNode("div", [trigger, input, list], attrs: Some(HashMap<String, String>([("class", "el-upload")])))
    }

    func buildList(): IComponent {
        let files = this._files.get()
        if (files.size == 0) {
            return VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-upload-list")])))
        }
        let items = ArrayList<IComponent>()
        for (f in files) {
            items.add(this.buildItem(f))
        }
        VNode("div", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-upload-list")])))
    }

    func buildItem(f: UploadFile): IComponent {
        // 移除按钮
        let removeH: ActionHandler = { ctx =>
            this._files.set(uploadRemove(this._files.get(), f.url))
            PatchResult.ReRender
        }
        let remove = VNode("i", [text("×")], attrs: Some(HashMap<String, String>([("class", "el-icon el-upload-list__item-delete")]))).onClick(removeH)
        let nameSpan = VNode("span", [text(f.name)], attrs: Some(HashMap<String, String>([("class", "el-upload-list__item-name")])))
        let itemAttrs = HashMap<String, String>()
        itemAttrs["class"] = "el-upload-list__item"
        itemAttrs["data-upload-url"] = f.url
        VNode("div", [nameSpan, remove], attrs: Some(itemAttrs))
    }
}
