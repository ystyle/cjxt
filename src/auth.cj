// 通用认证钩子：应用提供 token 校验回调，框架在 WS 连接恢复会话时调用，
// 校验通过返回要写入会话上下文的信息（uid/角色等标记）
package cjxt

import std.collection.HashMap

/// 会话上下文中的令牌 key：登录动作写入该 key 后，框架会自动同步给前端
/// （前端存 localStorage，WS 重连时回传用于恢复会话）
public let TOKEN_KEY = "token"

public class AuthHooks {
    let validateToken: (String) -> Option<HashMap<String, String>>

    public init(validateToken: (String) -> Option<HashMap<String, String>>) {
        this.validateToken = validateToken
    }

    public func doValidateToken(token: String): Option<HashMap<String, String>> {
        this.validateToken(token)
    }

    private static var inst: Option<AuthHooks> = None

    /// 配置 token 校验钩子（后配置者生效，与 RouteRegistry 覆盖语义一致）
    public static func setup(validateToken: (String) -> Option<HashMap<String, String>>): Unit {
        inst = Some(AuthHooks(validateToken))
    }

    /// 测试清理用
    public static func reset(): Unit {
        inst = None
    }

    public static func global(): Option<AuthHooks> {
        inst
    }
}
