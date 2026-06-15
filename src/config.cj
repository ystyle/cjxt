package cjxt

public struct AppConfig {
    let primaryColor: String
    let fontFamily: String
    let borderRadius: String

    public init(primaryColor!: String = "#1890ff", fontFamily!: String = "-apple-system, BlinkMacSystemFont, sans-serif", borderRadius!: String = "6px") {
        this.primaryColor = primaryColor
        this.fontFamily = fontFamily
        this.borderRadius = borderRadius
    }
}
