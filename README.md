# Musky desktop app

Flutter desktop client for the Musky Go/MySQL API.

## Implemented

- Desktop sign-in screen with keyboard submission, validation, loading and connection errors.
- Role-aware sidebar and workspace context. Super admins select a business before accessing tenant data; traders/admins are scoped to their own tenant.
- Client table with pagination, search within the current page, refresh and retry.
- Add/edit clients and archive/restore them through the API.
- Read-only team list and super-admin business list.
- Account details, password change and logout.
- Product create/edit/archive/restore with whole-pack stock and EGP pack prices.
- Draft invoice entry, searchable client/product selection, review, posting, cancellation, and voiding.
- Live dashboard totals for client debts, amounts owed, and net outstanding from posted invoices and voids.

Client reassignment and user/tenant creation are currently API-only. Payments, opening balances, taxes, discounts, partial returns, PDF/printing and offline synchronization are not yet implemented. Posting an invoice currently records its full total as client debt.

## Run

Start the backend with MySQL configured and bootstrap the first super admin using its README. No default login exists. Then:

```powershell
cd D:\Musky\app
flutter pub get
flutter run -d windows
```

The default API URL is `http://127.0.0.1:8080/api/v1`. For a hosted backend:

```powershell
flutter run -d windows --dart-define=MUSKY_API_URL=https://your-server.example/api/v1
```

The URL includes `/api/v1`. Remote servers require HTTPS; HTTP is permitted only for loopback development. Connection failures and invalid credentials appear in the sign-in form. Server credentials are never embedded in the app.

Sessions are held in memory only, so closing the app requires another login. Passwords and bearer tokens are not written to local files. Explicit logout revokes the server session; any 401 from an authenticated operation clears local account state. A failed network logout still clears local state and explains that the server session could not be revoked. Persistent sign-in can be added later using operating-system credential storage.

Windows builds require Visual Studio with the **Desktop development with C++** workload. That workload is not currently installed on this machine, so native Windows build/launch has not been verified. macOS/Linux builds require their corresponding operating systems and desktop toolchains. macOS outbound-network entitlements are enabled in debug/profile and release, following [Flutter networking guidance](https://docs.flutter.dev/data-and-backend/networking).

## Checks

```powershell
dart analyze lib test
flutter test
```

Tests cover login validation/errors, tenant-scoped requests, super-admin workspace switching, client create/edit/archive, expired sessions, logout, password changes, compact desktop layouts, and the real HTTP transport against a local test server. Widget tests use fake data, which is never loaded by the real app.

Optional widget-rendered previews (using fake test data): set `MUSKY_PREVIEW_DIR` to an existing directory and run `flutter test test/widget_test.dart --plain-name "desktop visual previews"`. On Windows the preview test loads Segoe UI when available. These previews do not replace a native desktop smoke test.

Repository: https://github.com/AhmedShalaby9/Musky_Flutter

Backend code is currently on that repository's `backend` branch. Use the local backend in `D:\Musky\backend` for the latest one-trader-per-tenant changes.

## Products and invoices

Run the latest local backend first so migration 003 creates the commerce tables. Product quantities are **whole boxes/packs**; pieces per pack is separate metadata. Enter prices as EGP decimals (up to two places); the API receives exact integer piastres.

Create a product and a client, then open Invoices, create a draft, select the client, add products and enter pack quantities. Save the draft, review its details, then choose Post invoice. Drafts do not reserve stock. Posting deducts stock and records client debt. Posted invoices cannot be edited; Void invoice requires a reason and restores stock/reverses debt. Cancel draft preserves a cancelled draft without changing stock.

Version conflicts mean another operation changed the record: close the editor, refresh the list and reopen it before saving. If saving a new draft times out, refresh the invoice list before creating another one to avoid duplicate drafts. Products and invoice/client pickers use server-side search with pagination. Invoice lists can be filtered by status.

The dashboard explicitly reports that only posted sales invoices and voids are included; payments and opening balances will be added separately. Widget previews include `products.png`, `invoice-editor.png` and `invoice-detail.png` using test-only sample data.



## how to build the app:

  flutter build windows --release

  if (Test-Path musky-client-windows.zip) {
      Remove-Item musky-client-windows.zip -Force
  }

  Compress-Archive `
    -Path build\windows\x64\runner\Release\* `
    -DestinationPath musky-client-windows.zip `
    -CompressionLevel Optimal