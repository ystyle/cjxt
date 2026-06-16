package cjxt

public struct AppConfig {
    let title: String
    let favicon: String
    let links: Array<(String, String)>
    let scripts: Array<String>
    let primaryColor: String
    let fontFamily: String
    let borderRadius: String
    let cssBundle: String

    public init(title!: String = "cjxt App", favicon!: String = "/favicon.ico", links!: Array<(String, String)> = [], scripts!: Array<String> = [], primaryColor!: String = "#1890ff", fontFamily!: String = "-apple-system, BlinkMacSystemFont, sans-serif", borderRadius!: String = "6px", cssBundle!: String = "") {
        this.title = title
        this.favicon = favicon
        this.links = links
        this.scripts = scripts
        this.primaryColor = primaryColor
        this.fontFamily = fontFamily
        this.borderRadius = borderRadius
        this.cssBundle = cssBundle
    }
}
