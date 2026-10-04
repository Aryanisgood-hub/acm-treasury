# 💰 ACM Treasury
> **Secure Finance Management for College Clubs**

A cross-platform **Flutter** application for managing club budgets, event expenses, bills, receipts, approvals, reports, and financial records — all from one secure platform.

Built with **Flutter** · **Supabase** · **PostgreSQL** · **Riverpod**

---

## ✨ Why ACM Treasury?

Managing a college club's finances through spreadsheets and physical receipts can quickly become messy and error-prone. 

ACM Treasury centralizes the entire financial workflow:
$$\text{Budget} \longrightarrow \text{Events} \longrightarrow \text{Expenses} \longrightarrow \text{Receipts} \longrightarrow \text{Approvals} \longrightarrow \text{Reports} \longrightarrow \text{Audit Trail}$$

* Every financial record remains fully traceable.
* Sensitive operations are protected directly at the database level, not just through the application UI.

---

## 🚀 Features

| Feature | Description |
| :--- | :--- |
| **📊 Financial Dashboard** | Track total budget, spending, remaining balance, and utilization at a glance. |
| **🎪 Event-Based Expenses** | Associate every bill with a specific club event. |
| **🧾 Digital Receipts** | Store receipts securely in private cloud storage. |
| **🔎 Search & Filters** | Find bills by event, person, amount, date, reason, or status. |
| **💰 Budget Approval** | Treasurer requests changes $\rightarrow$ President approves or rejects. |
| **🔐 Role-Based Access** | Enforce permissions for President, Vice President, Faculty Coordinator, and Treasurer. |
| **📝 Audit Trail** | Track who created, modified, or voided financial records. |
| **📤 Excel Export** | Generate structured financial backups with multiple sheets. |
| **📈 Reports** | Generate event-wise and monthly financial summaries. |
| **⚡ Realtime Updates** | Instant sync across all connected web and mobile clients. |
| **🛡️️ Database Security** | Hardened with PostgreSQL Row-Level Security (RLS), triggers, and database functions. |

---

## 💡 Core Workflow

```
                    ACM TREASURY
                         │
        ┌────────────────┼────────────────┐
        │                │                │
      Events            Bills           Budget
        │                │                │
        │             Receipts        Requests
        │                │                │
        └────────────────┼────────────────┘
                         │
                    Audit Trail
                         │
                   Reports & Backup
```

### Bill Lifecycle

```
Create ──► Active ──► Edit ──► Active ──► Void ──► Historical Record
```

> **Note on Records:** Bills are never permanently deleted from the database. Voided bills remain accessible for historical auditing but are automatically excluded from active financial calculations.

---

## 👥 Role-Based Access Control

ACM Treasury supports four distinct organizational roles:
* 👑 **President**
* 🧑‍💼 **Vice President**
* 🎓 **Faculty Coordinator**
* 💰 **Treasurer**

| Action | President | VP / Faculty | Treasurer |
| :--- | :---: | :---: | :---: |
| **View Dashboard** | ✅ | ✅ | ✅ |
| **View Events** | ✅ | ✅ | ✅ |
| **View Bills** | ✅ | ✅ | ✅ |
| **View Receipts** | ✅ | ✅ | ✅ |
| **View History** | ✅ | ✅ | ✅ |
| **Create Events** | ✅ | ✅ | ✅ |
| **Add Bills** | ❌ | ❌ | ✅ |
| **Edit Bills** | ✅ | ✅ | ✅ |
| **Void Bills** | ✅ | ✅ | ✅ |
| **Request Budget Change** | ❌ | ❌ | ✅ |
| **Approve Budget Change** | ✅ | ❌ | ❌ |

---

## 💰 Budget Approval Flow

```
   Treasurer
       │
       ▼
Budget Change Request
       │
       ▼
President Reviews ───► Approve ──► Budget Updated
       │
       └─────────────► Reject  ──► No Change
```

---

## 🔐 Security Architecture

Security is a foundational pillar of ACM Treasury. **Hiding a UI button is not security.** All authorization logic is directly enforced at the database layer via PostgreSQL and Supabase.

* **🔒 PostgreSQL Row Level Security (RLS):** Prevents unauthorized data queries or modifications.
* **👥 Role-based Authorization:** Checked dynamically per database query.
* **🚫 Permanent Bill Deletion Disabled:** Enforced via rules and triggers.
* **💰 Budget Change Protection:** Restricts monetary approvals strictly to the President role.
* **📝 Automated Audit Logging:** PostgreSQL triggers record user IDs and timestamps on mutations.
* **🔐 Private Receipt Storage:** Files stored securely with access provided exclusively through temporary signed URLs.
* **🚫 Public Registration Disabled:** Only active, authorized club members provisioned by administrators can log in.

---

## 💵 Financial Accuracy

To avoid standard floating-point binary representation errors during financial calculations, all monetary values are strictly converted and stored as **integer paise** ($1\text{ INR} = 100\text{ paise}$).

$$\begin{aligned}
\text{₹1} &\longrightarrow \text{100 paise} \\
\text{₹100} &\longrightarrow \text{10,000 paise} \\
\text{₹1,250} &\longrightarrow \text{125,000 paise} \\
\text{₹50,000} &\longrightarrow \text{5,000,000 paise}
\end{aligned}$$

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────┐
│           Flutter Application           │
├─────────────────────────────────────────┤
│ Screens ──► Riverpod ──► Repositories   │
└────────────────────┬────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│                Supabase                 │
├─────────────────────────────────────────┤
│ PostgreSQL · Auth · Storage · Realtime  │
└────────────────────┬────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│           PostgreSQL Security           │
├─────────────────────────────────────────┤
│       RLS · Triggers · Functions        │
└────────────────────┬────────────────────┘
```

---

## 🛠️ Tech Stack

### Frontend & App Framework
* **Flutter** — Cross-platform UI toolkit
* **Dart** — Programming language
* **Material 3** — Design system & UI components
* **Riverpod** — Reactive state management
* **go_router** — Declarative routing and navigation

### Backend & Infrastructure
* **Supabase** — Backend-as-a-Service (BaaS)
* **PostgreSQL** — Primary relational database
* **Supabase Auth** — Identity and session management
* **Row Level Security (RLS)** — Database authorization
* **Supabase Storage** — Secure cloud file storage
* **Supabase Realtime** — Live WebSocket data sync

### Key Dependencies
`supabase_flutter` · `riverpod` · `go_router` · `file_picker` · `image_picker` · `url_launcher` · `uuid` · `excel` · `share_plus` · `intl`

---

## 🗄️ Database Design

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│   MEMBERS    │ ──►   │    BILLS     │ ──►   │    EVENTS    │
└──────────────┘       └──────────────┘       └──────────────┘

┌──────────────────┐
│ BUDGET REQUESTS  │ ──► PRESIDENT APPROVAL
└──────────────────┘
```

### Core Database Tables
* `members` — User roles, profile data, and operational status
* `events` — Event details, dates, and associated expenditures
* `bills` — Individual expense records, receipt links, and status
* `budget_requests` — Financial change proposals and approval status
* `settings` — App-wide financial configurations and master budgets

---

## 📸 Screenshots

> *Add images to `docs/screenshots/` to display app preview visuals.*

| Financial Dashboard | Events |
| :---: | :---: |
| ![Dashboard](docs/screenshots/dashboard.png) | ![Events](docs/screenshots/events.png) |

| Bills | Budget Requests | Reports & Export |
| :---: | :---: | :---: |
| ![Bills](docs/screenshots/bills.png) | ![Budget Requests](docs/screenshots/budget.png) | ![Reports](docs/screenshots/reports.png) |

---

## 📁 Project Structure

```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── errors/
│   ├── router/
│   ├── theme/
│   └── utils/
├── models/
│   ├── member.dart
│   ├── event.dart
│   ├── bill.dart
│   ├── budget_request.dart
│   └── bill_filter.dart
├── services/
│   ├── auth/
│   └── export/
├── repositories/
│   ├── member/
│   ├── event/
│   ├── bill/
│   └── budget/
├── providers/
│   ├── auth/
│   ├── events/
│   ├── bills/
│   ├── budget/
│   ├── dashboard/
│   └── export/
├── screens/
│   ├── auth/
│   ├── dashboard/
│   ├── events/
│   ├── bills/
│   ├── budget/
│   ├── export/
│   ├── profile/
│   └── shell/
└── widgets/
    ├── cards/
    ├── dialogs/
    ├── empty/
    ├── error/
    └── loading/

supabase/
├── 0001_init.sql
├── 0002_add_roles.sql
├── 0003_fix_review_function.sql
└── 0004_security_tests.sql

test/
└── unit/
```

---

## ⚙️ Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install)
* Android Studio & Android SDK
* Google Chrome (for web testing)
* Git
* [Supabase Account](https://supabase.com/)

Verify your Flutter installation:
```bash
flutter doctor
```

### Setup Steps

1. **Clone the repository:**
   ```bash
   git clone <YOUR_REPOSITORY_URL>
   cd acm-treasury
   ```

2. **Configure Supabase:**
   * Create a new Supabase project and disable public sign-ups in Authentication settings.
   * Run the SQL migrations in order within the SQL Editor:
     1. `supabase/0001_init.sql`
     2. `supabase/0002_add_roles.sql`
     3. `supabase/0003_fix_review_function.sql`
   * Create users through Supabase Auth and seed them into the `members` table.

3. **Configure Environment Variables:**
   Copy `env.json.example` to `env.json`:
   ```bash
   cp env.json.example env.json
   ```
   Populate `env.json` with your project credentials:
   ```json
   {
     "SUPABASE_URL": "https://your-project.supabase.co",
     "SUPABASE_ANON_KEY": "your-publishable-key"
   }
   ```
   > ⚠️ **Security Warning:** Never expose or commit the Supabase `service_role` or secret admin keys inside your Flutter client application.

4. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

5. **Run the Application:**
   * **Web:**
     ```bash
     flutter run -d chrome --dart-define-from-file=env.json
     ```
   * **Android:**
     ```bash
     flutter devices
     flutter run -d <device-id> --dart-define-from-file=env.json
     ```

### 📦 Building Release APK

```bash
flutter build apk --release --dart-define-from-file=env.json
```
The output APK file will be available at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🧪 Testing

Run static code analysis:
```bash
flutter analyze
```

Run Flutter unit and widget tests:
```bash
flutter test
```

Run database security test suite in Supabase:
```bash
# Run supabase/0004_security_tests.sql inside your Supabase SQL editor
```
> The database security suite runs **13 strict authorization and policy verification checks**.

---

## 📤 Export & Backup

ACM Treasury features native support for generating formatted Excel workbooks containing multi-sheet financial data.

* 📅 **Event-wise reports:** Detailed breakdowns of all expenses tied to specific club activities.
* 📆 **Monthly summaries:** Aggregate financial metrics broken down by calendar month.
* 💰 **Financial balance sheets:** Comprehensive view of active vs. voided records and budget changes.

Exported backups can be shared directly via system share dialogs or saved locally.

---

## 🗺️ Roadmap

- [x] Authentication & Session Management
- [x] Role-Based Access Control
- [x] Event & Expense Management
- [x] Receipt Storage & Verification
- [x] Search, Filtering & Audit Trail
- [x] Budget Change Approval Workflows
- [x] Realtime Synchronization
- [x] Excel Data Backup & Export
- [x] Database Security Unit Tests
- [ ] In-app password change
- [ ] Dedicated bill history log
- [ ] Push notifications for pending approvals
- [ ] Dynamic member management UI
- [ ] Multi-club & multi-tenant support
- [ ] Advanced financial charts and PDF exports

---

## 🎓 Demonstrable Engineering Principles

This repository demonstrates the practical application of software engineering practices:

* **Security First:** Defense-in-depth where authorization rules exist independently of client-side code.
* **Financial Accuracy:** Zero-loss monetary math using integer representations.
* **Auditability:** Complete historical preservation with soft-delete patterns.
* **Clean Architecture:** Strict separation of UI, business logic (Riverpod), repository data layers, and backend services.

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature
   ```
2. Commit your changes:
   ```bash
   git commit -m "feat: add your feature"
   ```
3. Push to your branch:
   ```bash
   git push origin feature/your-feature
   ```
4. Open a Pull Request.

> **Important:** Never commit sensitive information, real financial statements, production credentials, passwords, or private API keys.

---

## 📄 License

No open-source license is currently specified. All rights remain reserved by the project authors until a license is added.

---

<p align="center">
  <b>ACM Treasury</b> — Secure • Transparent • Accountable<br>
  <i>Built with Flutter, Supabase, and PostgreSQL</i>
</p>