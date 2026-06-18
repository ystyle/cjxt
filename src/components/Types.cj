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

public enum ComponentKind {
    | Default | Primary | Success | Warning | Danger | Info | Plain

    public func asClass(): String {
        match (this) {
            case Default => ""
            case Primary => "primary"
            case Success => "success"
            case Warning => "warning"
            case Danger => "danger"
            case Info => "info"
            case Plain => "plain"
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

public enum ButtonNativeType {
    | Button | Submit | Reset

    public func asAttr(): String {
        match (this) {
            case Button => "button"
            case Submit => "submit"
            case Reset => "reset"
        }
    }
}

public enum ComponentSize {
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

public enum DividerDirection {
    | Horizontal | Vertical

    public func asClass(): String {
        match (this) {
            case Horizontal => "horizontal"
            case Vertical => "vertical"
        }
    }
}

public enum ContentPosition {
    | Left | Center | Right

    public func asClass(): String {
        match (this) {
            case Left => "left"
            case Center => "center"
            case Right => "right"
        }
    }
}

public enum TextSize {
    | Default | Large | Small

    public func asClass(): String {
        match (this) {
            case Large => "large"
            case Default => ""
            case Small => "small"
        }
    }
}

public enum TagSize {
    | Default | Large | Medium | Small | Mini

    public func asClass(): String {
        match (this) {
            case Large => "large"
            case Default => ""
            case Medium => "medium"
            case Small => "small"
            case Mini => "mini"
        }
    }
}

public enum TagKind {
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

public enum TagEffect {
    | Dark | Light | Plain

    public func asClass(): String {
        match (this) {
            case Dark => "dark"
            case Light => "light"
            case Plain => "plain"
        }
    }
}

public enum SpaceDirection {
    | Horizontal | Vertical

    public func asClass(): String {
        match (this) {
            case Horizontal => "horizontal"
            case Vertical => "vertical"
        }
    }
}

public enum MenuMode {
    | Horizontal | Vertical

    public func asClass(): String {
        match (this) {
            case Horizontal => "horizontal"
            case Vertical => "vertical"
        }
    }
}

