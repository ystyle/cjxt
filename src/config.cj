package cjxt

public struct AppConfig {
    let title: String
    let favicon: String
    let primaryColor: String
    let fontFamily: String
    let borderRadius: String

    public init(title!: String = "cjxt App", favicon!: String = "/favicon.ico", primaryColor!: String = "#1890ff", fontFamily!: String = "-apple-system, BlinkMacSystemFont, sans-serif", borderRadius!: String = "6px") {
        this.title = title
        this.favicon = favicon
        this.primaryColor = primaryColor
        this.fontFamily = fontFamily
        this.borderRadius = borderRadius
    }
}
