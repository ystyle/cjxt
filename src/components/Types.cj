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

public enum ComponentSize2 {
    | Large | Default | Small

    public func asClass(): String {
        match (this) {
            case Large => "large"
            case Default => ""
            case Small => "small"
        }
    }
}

public enum TableColumnType {
    | Default | Selection | Index | Expand

    public func asClass(): String {
        match (this) {
            case Default => ""
            case Selection => "selection"
            case Index => "index"
            case Expand => "expand"
        }
    }
}

public enum TableAlign {
    | Left | Center | Right

    public func asClass(): String {
        match (this) {
            case Left => "left"
            case Center => "center"
            case Right => "right"
        }
    }
}

public enum TableFixed {
    | Left | Right

    public func asFixedAttr(): String {
        match (this) {
            case Left => "left"
            case Right => "right"
        }
    }
}

public enum SortOrder {
    | Ascending | Descending | None

    public func asClass(): String {
        match (this) {
            case Ascending => "ascending"
            case Descending => "descending"
            case None => ""
        }
    }

    public func next(): SortOrder {
        match (this) {
            case None => SortOrder.Ascending
            case Ascending => SortOrder.Descending
            case Descending => SortOrder.None
        }
    }
}

public enum Placement {
    | Top | TopStart | TopEnd
    | Bottom | BottomStart | BottomEnd
    | Left | LeftStart | LeftEnd
    | Right | RightStart | RightEnd

    public func asPopper(): String {
        match (this) {
            case Top => "top"
            case TopStart => "top-start"
            case TopEnd => "top-end"
            case Bottom => "bottom"
            case BottomStart => "bottom-start"
            case BottomEnd => "bottom-end"
            case Left => "left"
            case LeftStart => "left-start"
            case LeftEnd => "left-end"
            case Right => "right"
            case RightStart => "right-start"
            case RightEnd => "right-end"
        }
    }
}

public enum TooltipTrigger {
    | Hover | Click | Focus | ContextMenu

    public func asString(): String {
        match (this) {
            case Hover => "hover"
            case Click => "click"
            case Focus => "focus"
            case ContextMenu => "contextmenu"
        }
    }
}

public enum TooltipEffect {
    | Dark | Light

    public func asClass(): String {
        match (this) {
            case Dark => "dark"
            case Light => "light"
        }
    }
}

public enum ProgressKind {
    | Line | Circle | Dashboard

    public func asClass(): String {
        match (this) {
            case Line => "line"
            case Circle => "circle"
            case Dashboard => "dashboard"
        }
    }
}

public enum ProgressStatus {
    | None | Success | Exception | Warning

    public func asClass(): String {
        match (this) {
            case None => ""
            case Success => "success"
            case Exception => "exception"
            case Warning => "warning"
        }
    }
}

public enum AvatarShape {
    | Circle | Square

    public func asClass(): String {
        match (this) {
            case Circle => "circle"
            case Square => "square"
        }
    }
}

public enum AvatarFit {
    | Fill | Contain | Cover | None | ScaleDown

    public func asAttr(): String {
        match (this) {
            case Fill => "fill"
            case Contain => "contain"
            case Cover => "cover"
            case None => "none"
            case ScaleDown => "scale-down"
        }
    }
}

public enum DescriptionsDirection {
    | Horizontal | Vertical

    public func asClass(): String {
        match (this) {
            case Horizontal => "horizontal"
            case Vertical => "vertical"
        }
    }
}

public enum DescriptionsAlign {
    | Left | Center | Right

    public func asClass(): String {
        match (this) {
            case Left => "left"
            case Center => "center"
            case Right => "right"
        }
    }
}

public enum ResultIcon {
    | Primary | Success | Warning | Info | Error

    public func asClass(): String {
        match (this) {
            case Primary => "icon-primary"
            case Success => "icon-success"
            case Warning => "icon-warning"
            case Info => "icon-info"
            case Error => "icon-error"
        }
    }
}

