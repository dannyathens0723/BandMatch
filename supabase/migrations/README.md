# BandMatch Supabase 初期設計（Phase 1 / v1.3）

FlutterFlow + Supabase で BandMatch Phase 1 MVP を実装するための初期スキーマです。機能仕様書・プログラム仕様書 v1.3 を基にしています。キー、トークン、`service_role` は含めません。

## 実行順

Supabase SQL Editor で次の順に実行してください。

1. `migrations/001_initial_schema.sql`
2. `migrations/002_seed_master_data.sql`
3. `migrations/003_rls_policies.sql`
4. `migrations/004_public_master_data_read_policies.sql`
5. `migrations/005_public_member_search_view.sql`
6. `migrations/006_member_public_profile_details.sql`
7. `migrations/007_message_request_pending_uniqueness.sql`
8. `migrations/008_received_message_requests_view.sql`
9. `migrations/009_accept_request_create_room.sql`
10. `migrations/010_message_request_relationship_state.sql`

既存の本番データベースへそのまま流す用途ではなく、初期構築用です。実行前に対象プロジェクトが正しいことを確認してください。

## 設計の要点

- 主テーブル・中間テーブルともに UUID の `id` と `created_at` / `updated_at` を持ちます。
- `users.auth_uid` は `auth.users.id` を参照します。アプリ会員の `users` と、運営用の `admin_users` は分離しています。
- `account_status` は `active` / `suspended` / `withdrawn` の3値です。退会は論理削除で、メッセージ・レビュー履歴を消しません。
- PostgreSQL の配列列や enum 配列は使いません。FlutterFlow で複数選択を保存・検索しやすいように、`user_purposes`、`user_parts`、`user_genres`、`user_target_parts`、`user_recruiting_parts` を採用しています。バンドにも同様の中間テーブルがあります。
- `parts` は12種、`genres` は18種を `002` で投入します。`areas` は関東の都県・市区・駅の確定データを別途インポートする前提です。
- `media_portfolios` は Phase 1 の YouTube / SoundCloud 埋め込みURLのみを許可します。音源バイナリや添付ファイル用の列は設けていません。
- Phase 1 の画像は `users.avatar_url` と `ads.image_url` に URL を保存する想定です。Storage バケット・画像変換・署名URLの運用は、デザイン確定後に別マイグレーションで追加してください。音源のStorageアップロードは Phase 2 以降です。

## プロフィール4ブロックの対応

| ブロック | 保存先 |
|---|---|
| A. 利用目的 | `user_purposes`（`recruit` / `join` / `practice`、複数選択） |
| B. 自分の属性 | `users` + `user_parts` + `user_areas` |
| C. 目指すスタイル | `users` + `user_genres` + `user_target_parts` |
| D. 募集条件 | `users.is_recruiting`、募集条件列、`user_recruiting_parts` |

`groups` もスタイル・募集条件を同じ考え方で持ちます。`is_recruiting = false` のときは、アプリ側で募集条件ブロックを非表示にしてください。

## FlutterFlow 実装時の注意

- 他人の検索・詳細には `users` を直接クエリせず、`user_public_profiles` を使用してください。これによりメール、電話、生年月日、同意記録、招待追跡などは露出しません。
- 市区・駅の公開可否は `user_areas.show_on_profile` で保持します。他人向け表示には `user_public_areas` を使用してください。都県は常に表示可能です。
- 複数選択は、中間テーブルをリスト表示して削除し、選択時に1行追加する構成が最も扱いやすいです。FlutterFlowで配列フィールドを丸ごと更新する必要がありません。
- プロフィール作成の必須性（目的、パート、活動歴、エリア、ジャンル、表示名、生年月日、SMS確認）は、複数テーブルをまたぐためDBの単一 `CHECK` 制約では完結させていません。登録完了画面へ進む前にFlutterFlow側でチェックし、必要ならEdge Functionで最終検証してください。
- `phone`、`phone_verified`、`account_status`、`premium_boost`、`last_login_at` などはクライアント更新を禁止しています。SMS検証完了後の反映、ログイン日時、課金、運営操作は、Auth Hook / Edge Function / 安全なサーバー側処理から更新してください。
- `media_portfolios.platform` は `youtube` / `soundcloud` のみです。URL形式の細かな検証は、FlutterFlow入力検証またはEdge Functionで行ってください。

## メッセージとレビュー

### メッセージリクエスト

`message_requests` は `pending` / `accepted` / `rejected` を持ち、`note` は最大300字です。リクエストの受信者が承認する場合、通常の `UPDATE` ではなく次のRPCを呼び出してください。

```sql
select public.accept_message_request('<message_request_uuid>');
```

このRPCは、承認状態の更新、`message_rooms` の作成、`room_participants` の作成を1トランザクションで行います。したがって、承認済みなのにルームがない状態を避けられます。グループを送受信者にした場合は、その時点のバンド管理者を参加者に展開します。

相互に `pending` が存在する場合の自動承認は、送信前に逆向きのリクエストを検索し、見つかったIDに同RPCを呼ぶカスタムアクションまたはEdge Functionで実装してください。ポリモーフィックな送受信者（個人/バンド）を安全に扱うため、単純なDBトリガーではなくこの明示フローにしています。

メッセージ本文は1〜2000字、種別は `text` / `stamp` です。`room_participants` にいるユーザー以外は、RLSによりルーム・発言・参加者を読めません。既読 (`message_reads`) はPhase 1では本人以外に見せない設計です。

### レビュー

レビューは承認済みルームの当事者に限り作成できます。`blind_until`、`is_published`、`published_at` を持ち、双方の逆向きレビューが揃った時点、または投稿から14日後に公開可能です。

14日経過分の公開には、運用側で `public.publish_due_reviews()` を定期実行してください。この関数はアプリ利用者には実行権限を付与していません。Supabase Cron / Edge Function / 安全な管理ジョブのいずれかから実行します。

## RLSと運用権限

`003_rls_policies.sql` は全テーブルでRLSを有効にします。主な境界は次のとおりです。

- 非公開の個人データ、同意履歴、通報、ブロック、招待、既読は本人または運営のみ。
- メッセージリクエストは送信側・受信側の当事者だけ。
- ルーム・メッセージは `room_participants` の参加者だけ。
- `blocks` は相互の検索プロフィール、選択項目、公開メディアを非表示にします。
- 凍結・退会ユーザー、凍結・退会グループは検索公開から除外します。
- `admin_users` は別の `auth.users` アカウントで管理します。最初の運営アカウントはSQL Editorから登録し、以降は運営画面または安全なバックエンド経由で追加してください。
- `subscriptions` と `payment_history` はPhase 2の器です。ユーザーは自分の履歴を読むだけで、Stripe Webhook等の信頼できるサーバー側処理が書き込みます。

## ログイン前のマスターデータ読み取り

`004_public_master_data_read_policies.sql` は、RLSを有効に保ったまま
`parts`、`genres`、`areas` の有効な行だけを `anon` と `authenticated` に公開します。
書き込み権限は追加しません。ユーザー、メッセージ、レビュー、通報、ブロック、課金関連などの
ユーザー生成・非公開テーブルのポリシーは変更しません。

## メンバー検索

`005_public_member_search_view.sql` は、認証済み利用者用の
`member_search_profiles` ビューを作成します。このビューはアクティブな他ユーザーだけを返し、
ブロック関係と自分自身を除外します。メールアドレス、電話番号、認証ID、生年月日、管理情報、
決済情報などはビューに含めません。`users` テーブルへのSELECT権限や既存RLSは変更しません。

## メンバー詳細

`006_member_public_profile_details.sql` は、`member_search_profiles` の公開・除外条件を引き継いだ
メンバー詳細用ビューを作成します。追加する列は `favorite_artists`、`gear`、
`activity_frequency`、`activity_days` のみです。いずれも既存の公開プロフィール設計に含まれる
フィールドであり、認証済み利用者だけがSELECTできます。

## メッセージリクエスト

`007_message_request_pending_uniqueness.sql` は、同じ個人送信者から同じ個人受信者へ
`pending` のリクエストを複数作成できないようにする部分ユニークインデックスです。
既存の `requests_insert_sender` ポリシーは、送信者本人、双方の有効状態、ブロック関係を確認するため、
RLSポリシーは変更しません。承認時は引き続き `accept_message_request(uuid)` RPC を使用します。

ユーザー自身の退会は次のRPCを使います。

```sql
select public.withdraw_current_user();
```

バンド管理者が退会する場合、最古の有効メンバーへ管理者権限を移し、後継者がいなければバンドを `suspended` にします。

招待コードは一覧公開しません。被招待者は次のRPCで登録します。

```sql
select public.redeem_invitation('<invite_code>');
```

## 管理・広告・Storageの補足

- 通報ステータスは `open` → `reviewing` → `closed` です。凍結・強制退会・通報クローズは運営アプリから実行し、必ず `admin_actions` に監査ログを残してください。
- `ads` は `area_target_id`、`is_active`、`priority` を持ちます。検索画面では対象都県の有効広告を `priority DESC` で取得し、カードN件ごとに「PR」表示で差し込んでください。
- `profile-images` / `ad-images` のStorageバケットを作る場合は、公開バケットにせず、`storage.objects` にバケット別のRLSポリシーを追加してください。ファイル名に `auth.uid()` を含めて所有者を判定する構成が安全です。広告画像の書き込みは管理者または信頼できるバックエンドに限定します。
- 管理アプリやWebhookで `service_role` を使う場合も、ブラウザ、FlutterFlowのクライアント設定、SQLファイル、Gitリポジトリには絶対に配置しません。
