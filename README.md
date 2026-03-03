# discourse-anonymous-topic-identity

A Discourse plugin that adds content-level anonymous posting with topic-scoped anti-sockpuppet codes.

## Features (V1)

- Composer toggle for anonymous topic/reply posting.
- User-entered alias with server-side validation.
- Stable anti-code per `user_id + topic_id`, different across topics.
- Post snapshot fields so alias changes only affect new posts.
- Alias-change audit events.
- Serializer fields for frontend rendering:
  - `anonymous`
  - `anonymous_display_name`
  - `anonymous_real_user_id` (staff only)
- For anonymous posts, public payload hides real `username`, `user_id`, role flags, and avatar.

## Data Model

### `anonymous_topic_identities`

- `user_id`
- `topic_id`
- `anti_code`
- `current_alias`
- `code_algo_version`
- `created_at`
- `updated_at`

Constraints:

- unique index on `(user_id, topic_id)`
- index on `(topic_id, anti_code)`

### `anonymous_alias_events`

- `identity_id`
- `old_alias`
- `new_alias`
- `changed_by_user_id`
- `created_at`

## Post Snapshots (`post_custom_fields`)

- `anon_alias_snapshot`
- `anon_code_snapshot`
- `anon_display_name_snapshot`
- `anon_identity_id`
- `anon_code_algo_version`

## Site Settings

- `anonymous_topic_identity_enabled`
- `anonymous_topic_identity_code_length` (default: 7)
- `anonymous_topic_identity_alias_min_length` (default: 2)
- `anonymous_topic_identity_alias_max_length` (default: 20)
- `anonymous_topic_identity_extra_denylist`
- `anonymous_topic_identity_secret_key`

## Install

1. Add this plugin into your Discourse `plugins` directory.
2. Rebuild Discourse.
3. Run migrations and enable `anonymous_topic_identity_enabled`.

## Notes

- Anonymous mode is opt-in per post.
- Alias collisions in the same topic are allowed by design.
- Existing historical posts are not backfilled after alias changes.
