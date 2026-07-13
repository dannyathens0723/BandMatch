# BandMatch Flutter app

BandMatch Phase 1 MVP のFlutter Webアプリです。Supabase の公開URLと公開キーだけを
`--dart-define` で渡します。`service_role` キーやその他の秘密情報はアプリに渡さないでください。

## ローカル起動

1. Supabase プロジェクトで、`supabase/migrations/001_initial_schema.sql` から
   `010_message_request_relationship_state.sql` までを番号順に適用します。
2. `app` ディレクトリで依存関係を取得します。

   ```powershell
   flutter pub get
   ```

   Windowsでプラグインのシンボリックリンク作成エラーが出た場合は、Windowsの
   **開発者モード**を有効にしてからもう一度実行してください。

3. Supabase Dashboard の **Project URL** と **Publishable key**（旧Anon key）を使い、Chromeで起動します。

   ```powershell
   flutter run -d chrome --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable-or-anon-key>
   ```

初回表示時はメールアドレスを入力し、届いたマジックリンクを開いてください。
Supabase Dashboard の **Authentication > URL Configuration** で、ローカルのURL（例:
`http://localhost:*`）を Redirect URLs に許可しておく必要があります。リンクから戻ると、
プロフィール設定画面が表示されます。表示名、生年月日、利用目的、担当パート、経験レベル、
ジャンルを保存するとホーム画面へ進みます。エリアはマスターデータを投入済みの場合だけ必須です。
ホーム画面の「メンバーを探す」から、アクティブな他メンバーの公開プロフィールを確認できます。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
