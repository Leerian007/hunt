# Steam 登录接入

实现以 `api_contract.md` 为准，使用后端签发的 Bearer Token。客户端不携带 Steam API Key，不把 SteamID64 当作认证凭证。

## 启动与部署

开发模式：Web/iOS 默认 http://localhost:8080/api/v1，Android 模拟器默认 http://10.0.2.2:8080/api/v1。发布模式默认 https://api.hunt1896.app/api/v1。通过编译环境变量切换：

```sh
flutter run -d chrome --dart-define=API_BASE_URL=https://api.hunt1896.app/api/v1
```

Web 后端返回地址为 `https://hunt1896.app/auth/callback?token=...&steam_id=...`。
站点需将 `/auth/callback` rewrite 到 Flutter 的 `index.html`；API 的 CORS 需允许前端域名及 Authorization 请求头。
本地 Web 调试需要后端将 web 平台回调切到实际 localhost 地址；仅修改 API_BASE_URL 不会修改后端回调。

Mobile 使用外部浏览器登录，回跳 `hunt1896://auth/steam?token=...&steam_id=...`。
Android 已配置 INTERNET 权限、scheme=hunt1896、host=auth、path=/steam；iOS 已注册 scheme，Dart 再校验 host/path。
已禁用 Flutter 默认 deep linking，交由 app_links 接管。Android/iOS 的冷启动与前台回跳均监听。

## 会话生命周期

- 登录：GET `/auth/steam/login-url?platform=web|mobile`，仅打开 Steam 官方 HTTPS 登录地址。
- 回调：检查 URI 和参数，写入 SharedPreferences 后请求 `/auth/session` 验证 Token、SteamID 和有效期，再请求 `/players/{steam_id}/summary`。
- 启动：恢复本地 Token，验证会话并重新拉取玩家资料。
- 401：统一删除本地 Token/SteamID 并将 Riverpod 状态切换为未登录。
- 退出：清理本地会话。契约无服务端退出接口，因此不宣称撤销服务器 Token。
- Web 收到回调时移除地址栏中的 token/steam_id，避免它们继续留在当前历史记录中。

按需求使用 SharedPreferences 保存 `auth_token` 与 `steam_id64`（旧 steam_token 会自动迁移）。SharedPreferences 并非加密凭据库；Web 应使用 HTTPS，且回调页面/反向代理不要记录敏感查询参数。后端负责 OpenID 签名、nonce、return_to 与登录发起状态验证。

玩家昵称与头像来自 summary；生涯指标来自 stats；分页战绩来自 matches。正式应用不再引用 Mock。后端未提供的等级、转生、时长、ACS、招牌武器、爆头率显示“—”，不填入演示值。

登录按钮的 Steam 标志来自 Valve 官方资源 `https://store.cloudflare.steamstatic.com/public/shared/images/header/logo_steam.svg`，保存在 assets/icons/steam_logo.svg，避免登录按钮依赖额外网络请求。Steam 标志属于 Valve。

Windows 主机如提示插件 symlink 不可用，需在 Windows 设置中启用开发者模式；这属于构建环境配置，不应通过应用代码绕过。iOS 构建需 macOS/Xcode。

## 本地网络与数据管理

- Android debug manifest 允许本地 HTTP；release 应配置 HTTPS。
- iOS 允许本地网络访问。真机的 localhost 指向手机本身，请通过 API_BASE_URL 配置可达的开发机地址或 HTTPS 域名；不要把模拟器地址用于真机。
- HTTPS Web 页面不能请求 HTTP API，部署时使用同为 HTTPS 的地址，并配置 CORS。
- profileProvider 并发请求 summary/stats；matchProvider 使用服务端 filter 和分页。
- 下拉刷新同时刷新资料和第一页战绩，接近列表底部加载下一页；加载更多失败保留已有记录，重试相同页码。
- 切换筛选或账号会创建新的战绩状态，旧请求完成后不会覆盖新列表。401 清除本地账号信息及全局登录态，页面回到登录入口。

## 登录控制器与启动屏

- auth_controller.dart 中的 AuthNotifier 统一处理获取登录 URL、外部浏览器跳转、回调去重和订阅释放。
- url_launcher 使用 externalApplication；Web 使用 _self 在当前页跳转，避免异步获取 URL 后新窗口被拦截。
- main.dart 的启动 Gate 显示暗色 Splash，等待冷启动回调或本地会话校验完成。会话操作最多等待 12 秒，初始平台链接最多等待 2 秒。
- 会话超时显示未登录入口和恢复重试；保留本地凭证供重试。无效/过期会话和 401 清理凭证。晚到响应不会把界面重新切换成已登录。
- 会话验证成功后才由 profile/match providers 拉取资料和战绩，资料请求失败不会改变已验证的登录身份。
- Web 处理首屏 /auth/callback、浏览器 popstate 和 Flutter RouteInformation。回调后清除地址栏 token/steam_id。
- 页面资料、战绩和加载更多均有进度指示器；失败时提供暗色金字重试按钮。
