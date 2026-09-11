# API v1

Base URL: `http://127.0.0.1:8080/api/v1`. JSON requests require `Content-Type: application/json`. All endpoints except login require `Authorization: Bearer <access_token>`. Unknown JSON fields are rejected. Bodies are limited to 64 KiB. Dates are UTC.

Errors use `{"error":"message"}`. Invalid input: 400; missing/expired authentication: 401; denied role: 403; missing or out-of-tenant resource: 404; duplicate email or last-admin removal: 409; wrong content type: 415; login throttling: 429. Unexpected database errors do not expose SQL or credentials.

List endpoints accept `limit=1..100` (default 50) and nonnegative `offset` (default 0), returning `{"data":[],"limit":50,"offset":0}` ordered by ID. Lists include inactive records, with their `active` flags, so desktop administration can restore them.

## Authentication

| Method | Path | Body / result |
| --- | --- | --- |
| POST | `/auth/login` | `{"email":"owner@example.com","password":"your password"}`; returns token, expiry and user |
| GET | `/me` | Current user's `id`, `tenant_id` (null for super admin), `name`, `email`, `role`, `active`, `created_at` |
| POST | `/auth/logout` | No body; revokes current session; 204 |
| PUT | `/me/password` | `{"current_password":"old password","new_password":"new password"}`; revokes all sessions; 204; log in again |

Passwords must be 12–72 UTF-8 bytes. Emails are trimmed, lowercased and globally unique. Passwords/hashes are never returned. Tokens are random opaque strings, not JWTs. The desktop client must securely store a token and return to login after 401.

## Tenant administration (super admin)

| Method | Path | Behavior |
| --- | --- | --- |
| GET | `/tenants` | Paginated businesses |
| POST | `/tenants` | Create business and initial admin atomically; 201 |
| PATCH | `/tenants/:tenantID` | Change `name` and/or `active`; 200. Deactivation revokes tenant sessions. |

Create example:

```json
{
  "name": "Musky Trading",
  "admin": {
    "name": "Ahmed",
    "email": "ahmed@example.com",
    "password": "replace-with-a-unique-password"
  }
}
```

Returns `{"id":1,"name":"Musky Trading","active":true,"admin_id":2}`. The initial admin role is fixed to `admin`. Business/admin names are required and limited to 150 characters.

## Users

Prefix: `/tenants/:tenantID/users`. Super admins may select a tenant; admins may only use their own. Traders cannot access user management (use `/me` for their profile).

| Method | Path suffix | Behavior |
| --- | --- | --- |
| GET | empty | List tenant users |
| POST | empty | Create user; 201 |
| GET | `/:id` | Get tenant user |
| PATCH | `/:id` | Update allowed fields; 200 |
| DELETE | `/:id` | Deactivate user and revoke sessions; 204 |

Creation body:

```json
{"name":"Trader One","email":"trader@example.com","password":"replace-with-a-unique-password","role":"trader"}
```

PATCH accepts any nonempty combination of `name`, `email`, `password`, `role`, `active`. It never accepts `tenant_id` or `id`. Only the super admin may create/manage admins; a tenant admin can create/manage traders. No API permits a `super_admin` role assignment. The last active admin cannot be deactivated or demoted. Changing password, role, email or active status revokes sessions. Restore using `{"active":true}`.

## Clients

Prefix: `/tenants/:tenantID/clients`. All authenticated roles can read/create/edit within an authorized tenant. Clients are shared within a tenant, not limited to their responsible user.

| Method | Path suffix | Behavior |
| --- | --- | --- |
| GET | empty | List clients |
| POST | empty | Create client; 201 |
| GET | `/:id` | Get client |
| PATCH | `/:id` | Update supplied fields; 200 |
| DELETE | `/:id` | Archive client; admin/super admin only; 204 |

Creation example:

```json
{
  "name": "Client One",
  "phone": "01000000000",
  "email": "client@example.com",
  "address": "Cairo",
  "notes": "Business contact"
}
```

`name` is required (1–150 characters). Optional fields: `phone` (40), `email` (valid email or empty, max 254), `address` (500), `notes` (2000), `user_id`, `active`. `user_id` defaults to the authenticated tenant user; the super admin must specify an active tenant user explicitly. Admins may assign/reassign to another active user in the same tenant; traders can only use their own ID during creation and cannot reassign. Only admins/super admins can set `active` (archive/restore). PATCH supports the same fields, all optional, and requires at least one supplied value. Clear optional text with an empty string.

Responses contain `id`, `tenant_id`, `user_id`, the contact fields, `active` and `created_at`. Client login, balances, products and invoice endpoints are not part of this increment.
