# BandMatch Flutter app

BandMatch Phase 1 MVP のFlutter Webアプリです。Supabase の公開URLと公開キーだけを
`--dart-define` で渡します。`service_role` キーやその他の秘密情報はアプリに渡さないでください。

## ローカル起動

1. Supabase プロジェクトで、`supabase/migrations/001_initial_schema.sql`、
   `002_seed_master_data.sql`、`003_rls_policies.sql` の順に適用します。
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

マイグレーションのRLSでは `parts` と `genres` を `authenticated` ロールだけに公開しています。
初回表示時はテスト用サインイン欄にメールアドレスを入力し、届いたリンクを開いてください。
Supabase Dashboard の **Authentication > URL Configuration** で、ローカルのURL（例:
`http://localhost:*`）を Redirect URLs に許可しておく必要があります。戻ると、画面には有効な
`parts`（12件）と `genres`（18件）が表示されます。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
