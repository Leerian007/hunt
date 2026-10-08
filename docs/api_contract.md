# Hunt 1896 Auth & Profile API 契约

- Base URL: https://api.hunt1896.app/api/v1
- Web 回调: https://hunt1896.app/auth/callback
- Mobile Deep Link: hunt1896://auth/steam

## 接口定义
1. GET /auth/steam/login-url?platform={web|mobile}
   - 返回: {"code": 0, "data": {"login_url": "https://steamcommunity.com/openid/login..."}}
   - 本地后端实测使用 data.url；客户端同时兼容 url 和 login_url。
2. GET /auth/session (Header: Authorization: Bearer <token>)
   - 返回: {"code": 0, "data": {"valid": true, "steam_id": "76561198...", "expires_at": "..."}}
3. GET /players/{steam_id}/summary (Header: Authorization: Bearer <token>)
   - 返回: {"code": 0, "data": {"steam_id": "...", "persona_name": "...", "avatar_full": "..."}}
## 生涯统计和战绩（后端提供的响应结构）

4. GET /players/{steam_id}/stats
   - data 字段：steam_id, total_matches, extracted_matches, win_rate,
     extraction_rate, total_kills, total_deaths, total_assists, kda,
     total_bounty_extracted, current_mmr, mmr_stars。
   - win_rate / extraction_rate 均为 0–1 小数。
5. GET /players/{steam_id}/matches?page=1&size=20&filter=all
   - data: {"total": 56, "pages": 6, "list": [...]}
   - list 的 MatchRecord 使用 sync_spec.md 中的 snake_case 字段，
     mmr_stars 可缺省。其他附加字段目前不参与卡片渲染。
   - 按最终约定：page 从 1 开始、filter=all/extracted/dead，默认 size=20。

API 外层仍为 {"code": 0, "message": "success", "data": ...}。
