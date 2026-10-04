# ACM Treasury

A finance management app for a college club, built with **Flutter** and **Supabase**.
It records every expense against an event, keeps the receipt, tracks the club budget,
and keeps a full audit trail of who did what and when.

> Money is stored as integer **paise** (₹1,250 = `125000`) to avoid rounding errors.

## Features

- **Dashboard**: total budget, total spent and remaining balance, calculated live from active bills; spending by event; recent bills; budget-used bar.
- **Events**: every bill belongs to an event; each event shows its bill count and total.
- **Bills**: add, edit and void bills with a receipt (camera, gallery, image or PDF). Voided bills stay on record but never count toward totals.
- **Search and filters**: by reason, event, person, amount, date range and status.
- **Budget requests**: Treasurers request a change; only the President can approve or reject. The budget changes only through the approval.
- **Export and backup**: full Excel backup (six sheets), event report and monthly report, shared from the phone.
- **Audit trail**: who added a bill, who last changed it, who voided it and why; every change is logged in the database.
- **Live updates** on every screen, no refresh needed.
- Works on **Android** (APK) and **web**.

## Roles

| Action | President | Vice President / Faculty Coordinator | Treasurer |
|---|---|---|---|
| View dashboard, events, bills, receipts, history | ✅ | ✅ | ✅ |
| Create events | ✅ | ✅ | ✅ |
| Add bills | ❌ | ❌ | ✅ |
| Edit and void bills | ✅ | ✅ | ✅ |
| Request a budget change | ❌ | ❌ | ✅ |
| Approve or reject budget changes | ✅ | ❌ | ❌ |

New roles can be added later with a small SQL migration (see `supabase/0002_add_roles.sql`).

## Tech stack

- **Flutter** (Dart), Material 3, **Riverpod** for state, **go_router** for navigation
- **Supabase**: Auth (email and password), PostgreSQL, Row Level Security, Storage, Realtime
- Packages: `supabase_flutter`, `file_picker`, `image_picker`, `url_launcher`, `uuid`, `excel`, `share_plus`, `intl`

## Security model

Security is enforced **in the database**, not only in the app. Hiding a button is only for convenience.

- **Row Level Security** on every table: only active club members can read data; only Treasurers can insert bills; nobody can delete bills.
- **Triggers** fill in "Added by" and timestamps from the signed-in user, so they cannot be faked, and freeze voided bills.
- **The official budget** can only change through the `review_budget_request()` database function, which only the President can run.
- **Receipts** are in a private Storage bucket, viewed through short-lived links.
- **Public sign-up is off**: accounts are created by the administrator and must have a row in `members`.
- `supabase/0004_security_tests.sql` runs 13 checks (and rolls them back) to confirm all of the above.

## Project structure

```
lib/
  main.dart, app.dart
  core/         constants, errors, router, theme, utils (money, formatters, export builder)
  models/       member, event, bill, budget request, bill filter
  services/     auth, export
  repositories/ member, event, bill, budget
  providers/    Riverpod providers (auth, events, bills, budget, dashboard, export)
  screens/      auth, dashboard, events, bills, budget, export, profile, shell
  widgets/      reusable cards, dialogs, empty/error/loading views
supabase/       SQL: schema, roles, fixes, security tests
test/           unit tests
```

## Setup

### 1. Supabase

1. Create a project at [supabase.com](https://supabase.com) (pick the region closest to you).
2. In **Authentication → Sign In / Providers**, turn **off** "Allow new users to sign up".
3. In the **SQL Editor**, run these files in order, each in a new query tab:
   1. `supabase/0001_init.sql`
   2. `supabase/0002_add_roles.sql`
   3. `supabase/0003_fix_review_function.sql`
4. In **Authentication → Users**, create the club's users (tick **Auto Confirm User**) and copy each user's UID.
5. Add them as members (use your own values; never commit real emails or UIDs):

   ```sql
   insert into public.members (id, name, email, role) values
    ('USER-UUID', 'Full Name', 'name@example.com', 'president');
   -- roles: president, vice_president, faculty_coordinator, treasurer

   update public.settings set total_budget = 5000000;  -- ₹50,000, in paise
   ```
6. Run `supabase/0004_security_tests.sql`. Every row should say **PASS**.

### 2. Flutter app

Requirements: Flutter (stable), Android SDK, and Chrome for web testing. Check with `flutter doctor`.

```bash
flutter pub get
cp env.json.example env.json      # on Windows: copy env.json.example env.json
```

Edit `env.json` with your **Project URL** (without `/rest/v1/`) and your **publishable (anon) key**. Never use the `secret` or `service_role` key in the app.

```bash
flutter run -d chrome --dart-define-from-file=env.json
flutter run -d <device-id> --dart-define-from-file=env.json   # a connected phone
flutter analyze
flutter test
```

`env.json` is git-ignored and must stay out of the repository.

### 3. Build an APK

1. Raise `version:` in `pubspec.yaml` for every release (the number after `+` must go up).
2. Make sure `android/app/src/main/AndroidManifest.xml` has the `INTERNET` permission and `android:label="ACM Treasury"`.
3. Build:

   ```bash
   flutter build apk --release --dart-define-from-file=env.json
   ```
4. The file is `build/app/outputs/flutter-apk/app-release.apk`. Always build from the same computer so members can install updates over the old version.

### App icon

Put `icon.png` and `icon_foreground.png` in `assets/icon/`, then run `dart run flutter_launcher_icons`.

## Administration

**Deactivate a member** (takes effect immediately; their old bills keep the correct "Added by"):

```sql
update public.members set active = false where email = 'name@example.com';
```

**Reset a forgotten password** (run in the SQL Editor; ask the member to change it afterwards):

```sql
update auth.users
set encrypted_password = extensions.crypt('TempPass2026', extensions.gen_salt('bf', 10)),
    updated_at = now()
where email = 'name@example.com';
delete from auth.sessions
where user_id = (select id from auth.users where email = 'name@example.com');
```

## Troubleshooting

| Problem | Fix |
|---|---|
| "Missing configuration" on start | Run with `--dart-define-from-file=env.json` |
| Build fails: "did not install NDK" | Install NDK `28.2.13676358` from Android Studio's SDK Manager (SDK Tools tab) |
| Build fails: plugin "compiled against android-34" | In `android/build.gradle.kts`, force plugin libraries to `compileSdk` 36 |
| App says it cannot reach the server | The free Supabase project may be paused: open the dashboard and click **Restore project** |
| "App not installed" on the phone | Uninstall the older copy first, or raise the `+` build number |

## Supabase free-plan limits

500 MB database, 1 GB file storage, 50,000 monthly users, and projects **pause after one week of inactivity**. The free plan has **no automatic backups**, so use **Profile → Export & backup** once a month and keep the file in Google Drive. Check Supabase's pricing page for current numbers.

## Roadmap

Password change inside the app, bill history screen, pending-request badge, member management screen, per-event budgets, expense categories, charts, PDF reports, academic years.

## License

Add a `LICENSE` file if you want others to reuse this code. Until then, all rights are reserved by the authors.
