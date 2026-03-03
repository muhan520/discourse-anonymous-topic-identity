# discourse-anonymous-topic-identity

面向 Discourse 的“话题级匿名身份”插件。  
用户可在发帖/回帖时使用匿名马甲，系统会为同一用户在同一话题内生成稳定的反精分码，并把展示名快照写入每条帖子。

## 已实现功能

- 发帖器支持匿名开关与马甲输入（话题和回帖都可用）。
- 服务端在发帖前强校验匿名昵称，避免仅靠前端校验。
- 同一 `user_id + topic_id` 生成固定反精分码；跨话题反精分码不同。
- 维护话题级身份表，记录当前马甲，支持后续改名。
- 马甲变更写入审计事件表（alias change event）。
- 每条匿名帖子写入展示快照（`马甲#反精分码`），历史帖子不被后续改名回写。
- 序列化输出匿名标记与匿名展示名，前台可直接渲染。
- 非 staff 视角下，匿名帖的 `name/username/display_username` 均使用匿名快照；头像替换为匿名头像。
- staff 仍可看到真实账号字段，并包含 `anonymous_real_user_id`。

## 发帖请求参数

插件扩展了 `/posts.json` 创建参数：

- `anonymous_enabled`: `true/false`
- `anonymous_alias`: 匿名昵称（启用匿名时必填）

示例：

```json
{
  "raw": "这是回帖内容",
  "topic_id": 123,
  "anonymous_enabled": true,
  "anonymous_alias": "伤心的小马"
}
```

## 匿名昵称校验规则

当 `anonymous_enabled=true` 时：

- 必填，不能为空
- 长度受站点设置限制（默认 2-20）
- 只允许中日韩文字母/字母/数字/`_`/`-`
- 会和 `reserved_usernames` + `anonymous_topic_identity_extra_denylist` 做禁用词校验

## 反精分码规则

- 算法：`HMAC-SHA256(secret_key, "#{user_id}:#{topic_id}")`
- 输出：base36 截断，长度由 `anonymous_topic_identity_code_length` 控制（实际夹在 6-12）
- 密钥优先使用 `anonymous_topic_identity_secret_key`，未配置时回退 `Rails.application.secret_key_base`

## 数据结构

### 表：`anonymous_topic_identities`

- `user_id`
- `topic_id`
- `anti_code`
- `current_alias`
- `code_algo_version`
- `created_at`
- `updated_at`
- 约束：唯一索引 `(user_id, topic_id)`；索引 `(topic_id, anti_code)`

### 表：`anonymous_alias_events`

- `identity_id`
- `old_alias`
- `new_alias`
- `changed_by_user_id`
- `created_at`

### 帖子快照：`post_custom_fields`

- `anon_alias_snapshot`
- `anon_code_snapshot`
- `anon_display_name_snapshot`
- `anon_identity_id`
- `anon_code_algo_version`

## 对外序列化字段

- `anonymous`: 是否匿名帖
- `anonymous_display_name`: 匿名展示名快照（`马甲#反精分码`）
- `anonymous_real_user_id`: 仅 staff 可见

## 站点设置

- `anonymous_topic_identity_enabled`（默认 `true`，客户端可读）
- `anonymous_topic_identity_code_length`（默认 `7`，范围 `6-12`）
- `anonymous_topic_identity_alias_min_length`（默认 `2`）
- `anonymous_topic_identity_alias_max_length`（默认 `20`）
- `anonymous_topic_identity_extra_denylist`（额外禁用昵称列表）
- `anonymous_topic_identity_secret_key`（反精分码密钥，secret）

## 安装与启用

1. 将插件放入 Discourse `plugins` 目录。
2. 重建 Discourse。
3. 执行 migration。
4. 后台启用 `anonymous_topic_identity_enabled`。

## 与自定义快速回复组件集成

如果站点使用自定义“快速回复”组件，发送时请同样透传：

- `anonymous_enabled`
- `anonymous_alias`

建议在前端用 `localStorage` 做全站记忆（如“是否匿名”“上次马甲”），但最终仍以服务端校验为准。

## 测试覆盖

- `spec/services/anonymous_topic_identity/alias_validator_spec.rb`
- `spec/services/anonymous_topic_identity/anti_code_generator_spec.rb`
- `spec/services/anonymous_topic_identity/identity_manager_spec.rb`
- `spec/integration/anonymous_topic_identity_posting_spec.rb`
- `spec/integration/anonymous_topic_identity_serializer_spec.rb`
