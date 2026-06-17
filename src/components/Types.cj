package cjxt.components

public enum ButtonKind {
    | Default | Primary | Success | Warning | Danger | Info

    public func asClass(): String {
        match (this) {
            case Default => ""
            case Primary => "primary"
            case Success => "success"
            case Warning => "warning"
            case Danger => "danger"
            case Info => "info"
        }
    }
}

public enum ButtonSize {
    | Large | Default | Small

    public func asClass(): String {
        match (this) {
            case Large => "large"
            case Default => ""
            case Small => "small"
        }
    }
}

public enum CardShadow {
    | Always | Hover | Never

    public func asClass(): String {
        match (this) {
            case Always => "always"
            case Hover => "hover"
            case Never => "never"
        }
    }
}

public enum RowJustify {
    | Start | End | Center | SpaceAround | SpaceBetween | SpaceEvenly

    public func asClass(): String {
        match (this) {
            case Start => "start"
            case End => "end"
            case Center => "center"
            case SpaceAround => "space-around"
            case SpaceBetween => "space-between"
            case SpaceEvenly => "space-evenly"
        }
    }
}

public enum RowAlign {
    | Top | Middle | Bottom

    public func asClass(): String {
        match (this) {
            case Top => "top"
            case Middle => "middle"
            case Bottom => "bottom"
        }
    }
}
