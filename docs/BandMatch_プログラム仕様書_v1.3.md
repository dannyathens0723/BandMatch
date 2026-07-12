# BandMatch プログラム仕様書 v1.3

**対象範囲:** Phase 1（MVP）
**関連文書:** BandMatch 機能仕様書 v1.3
**技術構成:** FlutterFlow（レスポンシブWeb）＋ Supabase（PostgreSQL）＋ Stripe
**作成日:** 2026年7月
**版の性格:** v1.2 までの内容に v1.3（プロフィール再設計・広告・デスクトップ対応）を統合した **完全統合版**。単体で Phase 1 の実装設計が把握できる。

---

## 改訂履歴

| 版 | 変更概要 |
|---|---|
| v1.0 | 初版（壁打ちで確定した設計） |
| v1.1 | 総点検：認証・連絡先、アカウント状態と論理削除、レビュー実体、規約バージョン管理、課金の器、各テーブル列定義、マスタ初期データ |
| v1.2 | 招待機能（友達＋バンド内）、運営向け管理機能をPhase 1へ、Phase 2予告の具体化、管理者退会時の権限引継ぎ・レビュー14日公開、細部定義（上限・デフォルト・JST・禁止ワード） |
| **v1.3** | **プロフィール4ブロック再構成、アプリ利用目的（必須・検索軸）、担当パート12択・ジャンル18択に刷新、真剣度→活動歴に統合、募集条件の分離（個人/バンド共通）、広告テーブル追加、デスクトップ幅レイアウト定義、必須項目の確定** |

---

## 目次

1. 本書の位置づけ
2. データベース設計（Supabase）
3. 主要ロジックの仕様
4. 招待機能（Phase 1）
5. 運営向け管理機能（Phase 1）
6. Phase 2 予告表示（グレーアウト）の定義
7. 画面別 動作定義（Phase 1）
8. レイアウト仕様（モバイル／デスクトップ）
9. 外部連携の実装方針
10. 制約・細部定義（上限・デフォルト・運用値）
11. 積み残しの宿題
12. v1.3 で確定した設計判断（サマリ）

---

## 1. 本書の位置づけ

「BandMatch 機能仕様書 v1.3」で定義した要件のうち、**Phase 1（MVP）を対象に実装方法を定義する**。FlutterFlow＋Supabase を前提とし、DB設計・画面動作・ロジック・外部連携を記述する。

> **基本思想:** データは拡張可能な形で持ち、機能の出し分けは後で行う。既読・メッセージ種別・課金・招待特典・座標距離・プレミアム上位表示などは「列・枠組みを先行用意し、有効化はPhase 2以降」とする。

---

## 2. データベース設計（Supabase）

すべてのテーブルに `id`・`created_at`・`updated_at` を持つ前提とし省略。**v1.3 追加・変更分は ▲** で示す。

### 2.1 テーブル一覧

| テーブル | 分類 | 役割 |
|---|---|---|
| `users` | ユーザー | 個人。認証・連絡先・プロフィール（4ブロック）・状態 |
| `groups` | ユーザー | バンド。独立した箱。スタイル・募集条件を保持 |
| `group_members` | ユーザー | 個人⇔バンド多対多。パート・権限(role) |
| `media_portfolios` | コンテンツ | 音源・動画（P1はURL埋め込み） |
| `areas` | マスタ | 都県／市区／駅の3階層（自己参照） |
| `user_areas` | ユーザー | ユーザーと活動駅の多対多 |
| `genres` ▲ | マスタ | 音楽ジャンル（18種に刷新） |
| `parts` ▲ | マスタ | 担当パート（12種に刷新。その他は自由記述） |
| `message_requests` | マッチング | メッセージリクエスト。status管理・メモ |
| `message_rooms` / `room_participants` / `messages` / `message_reads` | メッセージ | 会話・参加者・発言・既読 |
| `reviews` | 信頼 | レビュー。個人/バンド両対応・相互ブラインド |
| `blocks` / `reports` | 安全 | ブロック・通報 |
| `notifications` | 通知 | アプリ内通知 |
| `legal_documents` / `user_consents` | 規約 | 規約本文バージョン・同意記録 |
| `subscriptions` / `payment_history` | 課金 | 購読状態・課金履歴（P2で有効化） |
| `invitations` | 集客 | 招待（友達／バンド内）。コード・状態・追跡 |
| `admin_users` / `admin_actions` | 運営 | 運営アカウント・監査ログ |
| `ads` ▲ | 収益 | 検索一覧のネイティブ広告枠 |
| `waitlist` | 集客 | 事前登録（P0）メール収集 |

### 2.2 users（▲プロフィール4ブロックに再設計）

認証・状態・公開設定・招待追跡列（v1.1–v1.2）は継続。プロフィール項目を4ブロックに再構成する。

**認証・状態・システム列（継続）**
`auth_uid`, `email`（必須一意）, `phone`（必須）, `phone_verified`, `sns_providers`, `account_status`(active/suspended/withdrawn), `withdrawn_at`, `display_name`(1–30字・必須), `avatar_url`(Storage), `birth_date`（必須）, `gender`, `show_age`, `show_gender`, `last_login_at`, `premium_boost`（既定1.0）, `referral_source`, `invited_by`(fk→users)

**ブロックA：アプリ利用目的 ▲**
| 列 | 型 | 必須 | 説明 |
|---|---|:--:|---|
| `purpose` | enum[]（複数） | ○ | recruit（募集したい）/ join（加入したい）/ practice（練習相手を探す） |

**ブロックB：自分の属性 ▲**
| 列 | 型 | 必須 | 説明 |
|---|---|:--:|---|
| `part_ids` | int[]（fk→parts、複数） | ○ | 担当パート（12択） |
| `experience_level` | enum | ○ | beginner_new（はじめたばかり）/ beginner / experienced / pro_oriented |
| `activity_frequency` | enum | | monthly_1_2 / weekly_1_2 / daily |
| `activity_days` | text/jsonb | | 曜日・時間帯 |
| `plays_instrument` | enum | | plays / music_lover |
| `employment` | enum | | student / worker（社会人/学生。任意・検索フィルタ対象。v1.0から継続） |
| `favorite_artists` | text | | 自由記述・**検索非対象** |
| `gear` | text | | 所有機材（自由記述） |
| `bio` | text | | 自己紹介 0–1000字 |

**ブロックC：目指すスタイル ▲**
| 列 | 型 | 説明 |
|---|---|---|
| `style_orientation` | enum | copy（コピー中心）/ original（オリジナル中心） |
| `genre_ids` | int[]（fk→genres、複数） | 音楽ジャンル（18択） |
| `target_parts` | int[]（fk→parts、複数） | イメージする楽器構成（パート12択と同じ） |

**ブロックD：募集条件 ▲（`is_recruiting=true` のときのみ入力・表示）**
| 列 | 型 | 説明 |
|---|---|---|
| `is_recruiting` | bool | on/off（一覧に「募集中」タグ表示） |
| `recruiting_parts` | int[]（fk→parts） | 募集するパート |
| `recruit_gender` | enum | any / male / female |
| `recruit_age_min` / `recruit_age_max` | int | 募集する年齢範囲 |
| `recruit_purpose` | enum | light_session（軽くセッション）/ songwriting（曲作り）/ join_member（バンド加入者募集） |

**▲削除列:** `seriousness`（真剣度）→ `experience_level`（活動歴）に統合。
**参考（廃止された旧列との対応）:** 旧 `part_id`（単一）→ `part_ids`（複数）、旧 `genre_ids`（旧マスタ）→ 18種に刷新、旧 `experience_years`（経験年数・自由記述）は任意保持または `gear`/`bio` に集約可（Phase 1では非必須）。

> **登録必須（システム＋プロフィール）:** `display_name`・`birth_date`・`phone`(認証済=`phone_verified=true`)・`purpose`・`part_ids`・`experience_level`・活動エリア(`user_areas`に1件以上)・`genre_ids`。その他は任意。

### 2.3 groups（▲スタイル・募集条件を users と同名列で付与）

`name`, `avatar_url`, `bio`, `account_status`, `last_active_at`, `premium_boost`
**▲スタイル（C）:** `style_orientation`, `genre_ids`, `target_parts`
**▲募集条件（D）:** `is_recruiting`, `recruiting_parts`, `recruit_gender`, `recruit_age_min/max`, `recruit_purpose`
（旧 `recruiting_parts`・`activity_frequency` の単独定義は D ブロックに統合。バンドの活動頻度は必要に応じ `activity_frequency` を継続保持可。）

### 2.4 group_members

`user_id`, `group_id`, `part_id`, `role`(admin/member), `joined_at`
> 管理者退会時は `joined_at` が最古の member を admin へ自動昇格（第3.8節）。

### 2.5 マスタの刷新 ▲

| マスタ | 内容 |
|---|---|
| `parts`（12種） | ボーカル／ギター／ベース／ピアノ・キーボード／ドラム／パーカッション／管楽器／弦楽器／作詞作曲・アレンジャー／DJ／ダンサー／その他（自由記述可）。`sort_order` を持つ。 |
| `genres`（18種） | ポップス／ロック／ハードロック・ヘビーメタル／パンク・メロコア／ハードコア／スラッシュメタル・デスメタル／ビジュアル系／ファンク・ブルース／ジャズ・フュージョン／カントリー・フォーク／スカ・ロカビリー／ソウル・R&B／ゴスペル・アカペラ／ボサノバ・ラテン／クラシック／ヒップホップ・レゲエ／ハウス・テクノ／アニソン・ボカロ |
| `areas` | 都県／市区／駅の3階層（自己参照 `parent_id`・`level`）。関東の駅を網羅インポート。 |
| enum/小マスタ | `purposes`（利用目的3種）、`experience_levels`（活動歴4種）、`recruit_purposes`（募集目的3種）、`activity_frequencies`。 |

### 2.6 ads ▲（検索一覧のネイティブ広告）

| 列 | 型 | 説明 |
|---|---|---|
| `title` | text | 広告見出し |
| `image_url` | text | 画像（Storageまたは外部URL） |
| `link_url` | text | 遷移先 |
| `advertiser` | text | 出稿者（ライブハウス・スタジオ等） |
| `area_target` | fk→areas / text | エリアターゲティング（都県等） |
| `is_active` | bool | 掲載中フラグ |
| `priority` | int | 差し込み優先度 |

> 一覧に **数件ごとに1枠** を差し込み、カード上に「PR」バッジを表示する（第4.3節）。

### 2.7 message_requests（メモ添付）

`sender_type/id`, `receiver_type/id`, `status`(pending/accepted/rejected), `note`(0–300字), `responded_at`
> 承認時に `message_rooms` を生成し、`note` をルーム冒頭に表示（第3.1節）。

### 2.8 reviews（相互ブラインド＋14日ルール）

`reviewer_type/id`, `reviewee_type/id`, `room_id`, `rating`(1–5), `comment`, `is_published`, `submitted_at`
> 双方投稿まで `is_published=false`。片方のみ投稿でも `submitted_at` から14日で公開（第3.6節）。

### 2.9 invitations / admin_users / admin_actions

- `invitations`: `inviter_id`, `invite_type`(friend/band), `code`(一意), `target_group_id`, `target_part_id`, `invitee_email`, `status`(sent/registered/expired), `registered_user_id`, `reward_status`(P1は none 固定)
- `admin_users`: `email`, `role`(admin/moderator), `is_active`（ユーザー用 `users` とは分離）
- `admin_actions`: `admin_id`, `action_type`(suspend_user/unsuspend/force_withdraw/close_report 等), `target_type`, `target_id`, `reason`, `created_at`

（media_portfolios / message_rooms / room_participants / messages / message_reads / blocks / reports / notifications / legal_documents / user_consents / subscriptions / payment_history / waitlist の列は v1.1–v1.2 を継承）

> **Row Level Security（RLS）:** 本人（またはグループ管理者）以外は他者の非公開データ・メッセージ・リクエストを参照不可。凍結・退会ユーザーは検索・一覧に出現させない。運営操作は `admin_users` 認証下でのみ許可。

---

## 3. 主要ロジックの仕様

### 3.1 マッチング状態遷移
送信(pending)→承認(accepted：ルーム生成・メモ表示)／拒否(rejected)。rejected相手へは再送不可。両想い（相互pending）は自動accepted。有効期限なし。送信不可条件：自分自身・ブロック相手・退会/凍結ユーザー。

### 3.2 検索・並び順スコアリング
```
score = (w1*recency + w2*rating + w3*proximity) * premium_boost
```
- `recency` = `last_login_at` の新しさ
- `rating` = 公開済レビュー平均（コールドスタート時は重み軽め）
- `proximity` = エリア階層（都県/市区/駅の一致度）の段階評価
- `premium_boost` = Phase 1 は 1.0（無効）
- `account_status ≠ active` は除外。**重み(w1〜w3)の具体値は運用時に決定（第11章）。**
- 一覧は無限スクロールで **20件ずつ**。

### 3.3 検索フィルタ ▲
利用目的（`purpose`）・担当パート（`part_ids`）・地域（都県/市区/駅）・年齢・性別・ジャンル（`genre_ids`）・**活動歴（`experience_level`／旧・真剣度を置換）**・活動頻度（任意）・社会人/学生（`employment`）・**「メンバー募集中のみ」トグル（`is_recruiting`）**・音源ありトグル・最終ログイン。好きなアーティストは検索対象外。非公開項目（年齢・性別・市区・駅）はその条件でヒットしない（都県は公開固定）。

### 3.4 インライン音源再生
一覧は遅延起動＋1曲のみ再生（別カード再生で前を停止）。詳細（右パネル／詳細ページ）はその場埋め込み。

### 3.5 ブロック・通報
ブロックはサイレント化（相手に明示サインを出さず、検索・一覧からも消える）。通報はユーザー単位で運営へ。自動制限なし・運営手動判断。

### 3.6 レビュー（相互ブラインド／14日公開）
accepted相手のみ記入可（個人・バンド両対象）。双方投稿まで `is_published=false`。片方のみ投稿の場合、`submitted_at` から14日経過で片側だけでも公開。

### 3.7 認証・登録フロー
メール/SNS作成 → 電話番号SMS本人確認 → **アプリ利用目的の選択** → 生年月日・エリア・必須項目（表示名・パート・活動歴・ジャンル）入力 → 規約同意記録 → 一覧へ。

### 3.8 管理者退会時のバンド権限引き継ぎ
admin が退会（withdrawn）した場合、当該バンドの member のうち `joined_at` が最古の1名を admin へ自動昇格。member が一人もいない場合はバンドを凍結（suspended）扱いにし検索・一覧から除外。

### 3.9 広告の差し込みロジック ▲
検索一覧の描画時、`ads`（`is_active=true`）を `area_target`（ユーザーの活動都県）と `priority` で抽出し、**カード N 件ごとに1枠**を差し込む（差し込み間隔 N は運用値・第10章）。広告カードには「PR」バッジを付与し、通常カードと視覚的に区別する。

---

## 4. 一覧・広告・UI（v1.3）

### 4.1 検索一覧の要素
左上にロゴ「BandMatch」（Phase 1 は仮＝ワードマーク）。各カードに写真／アイコン、担当パート、活動エリア、ジャンル、**利用目的**、**「募集中」タグ（`is_recruiting`）**、インライン再生ボタン、評価（星）を表示。

### 4.2 広告枠
一覧のカード間に数件ごとに広告枠を差し込み（「PR」表記のネイティブ広告）。ライブハウス・スタジオ等の出稿・送客導線。

### 4.3 デスクトップ／モバイルの出し分け
FlutterFlow のブレークポイントで出し分ける（詳細は第8章）。

---

## 5. 招待機能（Phase 1）

ユーザー数がサービスの生命線であるため、招待を Phase 1 の必須機能とする。

- **友達招待:** 招待リンク／コード（`invitations.code`）を発行・共有。経由登録で `users.invited_by` を記録し `invitations.status=registered`。
- **バンド内招待:** バンド管理者が既存メンバーを招く（`invite_type=band`, `target_group_id`／任意で `target_part_id`）。承諾で `group_members` に追加。
- **特典・追跡:** Phase 1 は特典なし（`reward_status=none`）。Phase 2 で課金連動。`inviter_id × status=registered` で集客分析。

---

## 6. 運営向け管理機能（Phase 1）

通報対応の実務に必須のため、最低限の管理画面を Phase 1 に含める。ユーザー向けアプリとは **別アプリ／別権限（`admin_users`）**。

- **Phase 1 スコープ:** 通報の確認（`reports` 一覧・詳細、状態を open→reviewing→closed）、ユーザー凍結／解除（`account_status`）、強制退会（`account_status=withdrawn` 論理削除）、監査ログ（`admin_actions`）。
- **Phase 2 以降:** コンテンツ自動フィルタ、通報の自動集計・自動一時制限、運営ダッシュボード高度化。

---

## 7. Phase 2 予告表示（グレーアウト）の定義

主要機能のみを **グレーアウト＋「近日公開」ラベル** で予告し、タップで簡単な説明を表示する（全機能は並べない）。

| 予告する機能 | 表示場所 | タップ時の説明（例） |
|---|---|---|
| プレミアム | マイページ上部 | 「上位表示・高度検索などの有料プラン。近日公開」 |
| スタジオを探す／予約 | メッセージルーム内 | 「マッチした相手とスタジオ検索・予約。近日公開」 |
| グループチャット | メッセージ／グループ | 「3人以上でのグループ会話。近日公開」 |
| 日程調整 | メッセージルーム内 | 「候補日を送り参加可否を集計。近日公開」 |
| ファイル送付 | メッセージ入力欄 | 「画像・動画・音声の送付。近日公開」 |

> 上記以外のPhase 2機能（音源直接アップロード・既読表示・招待特典等）は、予告表示せず内部的に器のみ用意する。

---

## 8. 画面別 動作定義（Phase 1）

| 画面 | 主な表示要素 | 主なアクション／遷移 |
|---|---|---|
| 事前登録（P0） | サービス紹介・メール入力 | waitlist 追加 |
| 会員登録／ログイン | メール・SNS・電話SMS認証・利用目的・生年月日・エリア・必須項目・規約同意 | 登録/ログイン → 一覧 |
| 検索一覧 | カード（利用目的・募集中タグ・再生ボタン・評価）、フィルタ入口、広告枠、無限スクロール | 再生／詳細（右パネル）／フィルタ |
| 検索フィルタ | 利用目的・パート12・階層エリア・年齢・性別・ジャンル18・活動歴・活動頻度・社会人/学生・募集中トグル・音源トグル・最終ログイン | 条件適用 |
| プロフィール詳細 | 4ブロック（利用目的・属性・スタイル・募集条件）・ポートフォリオ・機材・評価・レビュー | 「メッセージを送る」→リクエスト（メモ）／通報 |
| グループ詳細 | バンド情報・スタイル・募集条件・メンバー・評価 | メッセージ／バンド内招待（管理者） |
| リクエスト一覧 | 受信/送信タブ、状態 | 承認／拒否 |
| リクエスト送信 | 相手情報・メモ入力（0–300字） | 送信 |
| メッセージルーム | 参加者名・発言(text/stamp)・冒頭メモ（日程調整/スタジオ/ファイル送付は近日公開） | 送信／スタンプ／ブロック／通報 |
| レビュー投稿 | 星5＋コメント、相互ブラインドの案内 | 投稿（両者投稿 or 14日で公開） |
| プロフィール編集 | 4ブロック各項目、公開/非公開トグル（年齢・性別・市区・駅）、募集中トグル、アイコン設定 | 保存 |
| 招待 | 招待リンク/コード、友達招待・バンド内招待 | 共有／発行 |
| マイページ | 自分の情報、リクエスト履歴、受領レビュー、招待、規約類、退会、ログアウト、プレミアム(近日公開) | 各遷移／退会（論理削除）／ログアウト |
| 規約類 | 各規約（バージョン表示） | 閲覧・（改定時）再同意 |

---

## 9. レイアウト仕様（モバイル／デスクトップ）▲

FlutterFlow のブレークポイントで同一プロジェクトから出し分ける。

### 9.1 モバイル（〜768px）
1カラム＋ボトムタブ（さがす・リクエスト・メッセージ・マイページ）。検索一覧は縦積みカード。プロフィール詳細は画面遷移。デザインはワイヤーフレーム v3（Bumble風）で確立済み。

### 9.2 デスクトップ（1280px想定）— 回遊型レイアウト
- **グローバルナビ:** 上部に横並び（ロゴ／さがす／リクエスト／メッセージ／マイページ）。
- **検索一覧:** 左にフィルタサイドバー、中央に **2〜3カラムのカードグリッド**、右にプロフィールパネル（カードクリックで右に開く回遊型／未選択時は広告）。広告は数件ごとに差し込み。
- **メッセージ:** 左に会話リスト、右にトークの2ペイン。
- **リクエスト一覧／送信・マイページ:** 中央カラム主体、必要に応じ右に補助情報。
- Phase 2機能はグレーアウト＋「近日公開」。

---

## 10. 外部連携の実装方針

| 連携先 | フェーズ | 方針 |
|---|---|---|
| YouTube / SoundCloud | P1 | URL埋め込み。一覧は遅延起動 |
| SMS本人確認 | P1 | 電話番号SMS認証（Supabase Auth または外部SMSプロバイダ／選定は運用時） |
| メール通知 | P1 | 重要イベントをアプリ内通知＋メール |
| Supabase Storage | P1（アイコン・広告画像）/P2（音源等） | 画像はP1から |
| Stripe | P2 | 課金（subscriptions/payment_history） |
| スタジオ予約 | P2→P3 | アフィリエイト→API直接予約 |

---

## 11. 制約・細部定義（実務標準値。運用で調整可）

| 項目 | Phase 1 の定義 |
|---|---|
| バンド所属・作成数 | 上限なし（掛け持ち自由） |
| バンド名の重複 | 許可（IDで区別） |
| 表示名 | 1–30文字 |
| 自己紹介(bio) | 0–1000文字 |
| メッセージ本文 | 1–2000文字 |
| リクエストのメモ | 0–300文字 |
| スタンプ | Phase 1は基本セット（15種程度） |
| 担当パート | 12択（その他は自由記述）・複数選択可 |
| 音楽ジャンル | 18択・複数選択可 |
| 必須項目 | 表示名・パート・活動エリア(駅)・ジャンル・生年月日・利用目的・活動歴（＋電話番号SMS認証を登録フローの必須ステップとする） |
| デフォルトアイコン | 未設定時はイニシャル＋自動配色のプレースホルダ |
| メッセージリクエスト送信制約 | 自分自身・ブロック相手・退会/凍結ユーザーには送れない |
| 広告差し込み間隔 | カード N 件ごとに1枠（N の具体値は運用調整） |
| 言語 | 日本語のみ（多言語は将来） |
| タイムゾーン | JST固定 |
| 禁止ワード／不適切コンテンツ | 投稿規約に基づく基本的な禁止ワードフィルタ（運用で拡充） |
| 通知の送信イベント | リクエスト受信／承認／新着メッセージ／レビュー公開／招待成立。うちメールは重要イベントに限定 |

---

## 12. 積み残しの宿題（運用しながら詰める）

- 並び順の重み（w1〜w3）とコールドスタート配慮の具体値：実データで調整。
- 広告差し込み間隔 N・エリアターゲティング精度の調整。
- SMSプロバイダの選定・送信コスト・到達率。
- 禁止ワード辞書の拡充、不適切画像の検知（Phase 2で自動化検討）。
- 年齢確認の強化・既読表示の有料解放（Phase 2）：データはP1から保持。
- 運営向け管理画面の詳細設計（別アプリ）。

---

## 13. v1.3 で確定した設計判断（サマリ）

1. **プロフィール4ブロック再構成:** A利用目的（必須・検索軸）／B自分の属性／C目指すスタイル／D募集条件（`is_recruiting=true` 時のみ・個人/バンド共通）。
2. **選択肢刷新:** `parts` 12択・`genres` 18択に刷新。`part_ids`・`genre_ids`・`target_parts` を配列で保持。
3. **真剣度の廃止:** `seriousness` を削除し `experience_level`（活動歴）に統合。
4. **利用目的の新設:** `purpose`(enum[]) を登録必須かつ検索の主要軸に追加。
5. **募集条件の分離:** ブロックD を個人・バンド共通で `is_recruiting` オン時のみ入力・表示。
6. **広告テーブル追加:** `ads` を新設し、検索一覧に数件ごと「PR」枠を差し込む。
7. **必須項目の確定:** 表示名・パート・エリア・ジャンル・生年月日・利用目的・活動歴（＋SMS認証ステップ）。
8. **社会人/学生（`employment`）は任意項目として継続**（検索フィルタ対象）。
9. **デスクトップ幅レイアウト定義:** 横並びグローバルナビ＋左フィルタ＋中央グリッド＋右パネル（回遊型）。モバイルは1カラム＋ボトムタブ。

---

**次工程:** 本設計（v1.3）を反映した **デスクトップ版ワイヤーフレーム**（Bumble風v3のデザイン言語）を作成する。運営向け管理画面は別アプリとして別途ワイヤー化。

— 以上 —
