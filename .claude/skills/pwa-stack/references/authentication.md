# Authentication: password or email OTP

Read this after the sign-in choice and before copying the init migration or
generating auth code. Keep the chosen method consistent across the UI, auth
context, API gateway, collection settings, and README. Generate both methods
only if the user explicitly requests both.

## Setup choices

Ask **Password** or **Email OTP** unless already specified. Email OTP means a
code delivered by email, without a user-chosen password; it is not an
authenticator-app TOTP or an SMS flow. When the user says "UTP" while referring
to the Chinese-learning email login, use this OTP pattern.

For OTP, also settle:

- **Account provisioning:** automatic account creation, as in the reference
  app, or invited/existing accounts only. Do not enable public registration
  without settling that choice. When signup is open, use the same email/code
  flow for signup and returning users.
- **Email delivery:** reuse the project's PocketBase SMTP and sender settings
  or document what must be configured. Keep credentials out of chat and source
  control; use the dashboard or the project's secret configuration. A local
  mail capture service can support development, but does not verify production
  delivery.

Record the chosen mode, provisioning policy, and outstanding mail setup in the
generated project documentation.

## Password mode

Keep the existing two-step roster picker and password form: a public
`/api/roster` returns active members' display names and avatars, then the user
selects their account and enters a password. Restrict the roster response to
the fields needed for sign-in; do not expose full user records. Authenticate with
`pb.collection("users").authWithPassword(identity, password)` through the app
origin. Retain only the password-mode roster rules in the init template and
keep OTP disabled. Document how operators create active app users.

## Email OTP mode: reference and frontend

Use the **web/PWA** implementation in `/home/maxime/repos/chinese-learning`,
especially:

- `frontend/src/components/EmailLogin.tsx` — shared email/code form and states.
- `frontend/src/pages/Login.tsx` — branded login shell and expired-session notice.
- `frontend/src/auth/AuthContext.tsx` — `loginWithOtp` and auth-store integration.
- `api/src/routes/email-auth.ts` — request/provisioning and verification guards.
- `pocketbase/pb_migrations/0052_email_otp.js` — OTP collection configuration.

Read those files when available. This reference remains sufficient if that
checkout is absent. Follow the flow and component structure, adapting the app
name, icon, language, fonts, and theme tokens. Do not import its Chinese study
features, native `mobile/` implementation, guest-account machinery, or social
providers unless requested.

Start directly on a reusable `EmailLogin` form in the branded login shell;
there is no provider picker when email OTP is the only method.

1. **Email:** a visible label and email field; trim and lowercase before
   submission. Use email keyboard/autocomplete, disable autocapitalization and
   spellcheck, and offer **Send sign-in code**. Explain automatic account
   creation only when that provisioning policy was selected.
2. **Code:** show **Check your email**, the destination address, and one labeled
   six-digit input. Use `type="text"`, `inputMode="numeric"`,
   `autoComplete="one-time-code"`, `pattern="[0-9]{6}"`, and `maxLength={6}`.
   Preserve leading zeroes. Support pasting a complete code with spaces removed
   and move focus to the code field when the challenge arrives.
3. **Verify:** enable **Verify and sign in** only for six digits. Show separate
   **Sending code…** and **Signing in…** states, prevent duplicate submissions,
   and disable competing actions while a request is pending.
4. **Recovery:** show the single-use expiry hint from `expiresIn`, a **Resend
   code in Ns** countdown from `resendAfter`, and **Use a different email**.
   A successful resend replaces the challenge, clears the code, and restarts
   the countdown. Changing email clears the challenge, code, and messages.
   Add **Other sign-in options** only when other methods actually exist.
5. **Feedback:** use `role="status"` for delivery notices, `role="alert"` for
   errors, and `aria-busy` on the form. Distinguish incorrect/expired codes,
   rate limits, and delivery/network failures. Preserve entered email and
   allow retry. Use the shared fields/buttons and light/dark styling, with
   readable code spacing and the mobile keyboard/safe-area checks.

Expose `loginWithOtp(otpId, code)` from `AuthContext` using
`pb.collection("users").authWithOTP(otpId, code)`. Let the SDK save its normal
token and record to the existing auth store; clear the expired-session flag
only after success. Retain the common refresh, expiry, logout, and account
cache-clearing behavior from `patterns.md` §6. Requesting a code or failing
verification must not clear or replace an existing session.

## Email OTP mode: API and collection

Keep the auth-only browser client and same-origin API boundary. Register these
explicit app routes before the generic PocketBase proxy:

| Route | Request | Successful response |
| --- | --- | --- |
| `POST /api/auth/email/request` | `{ email }` | `{ otpId, expiresIn: 600, resendAfter: 60 }` |
| `POST /api/collections/users/auth-with-otp` | `{ otpId, password: code }` | PocketBase's normal `{ token, record }` auth response |

The second route preserves the SDK's standard URL and response so
`authWithOTP` updates the auth store. `password` here is the six-digit code,
not an account password. The request route calls PocketBase's private
`/api/collections/users/request-otp` endpoint after applying the app's policy;
the browser must not bypass it through a generic request-OTP passthrough.

- Normalize and validate email, challenge, and code; forward only the allowed
  fields. Never accept roles, activation, verification, or account IDs from the
  unauthenticated caller.
- For automatic signup, look up the normalized email with the server client.
  Only if absent, create an unverified account with a cryptographically random,
  unshared password, `active: true`, and `role: "member"` when roles are enabled.
  Handle unique-email creation races by re-reading. Never reset an existing
  account's password, verification, activation, or role. Issue no session until
  mailbox ownership is verified.
- For invited-only signup, do not create unknown accounts. Return the same
  challenge-shaped response for unknown or inactive accounts without sending
  mail. PocketBase also returns an `otpId` for a nonexistent email; that is not
  evidence that delivery occurred. Avoid disclosing account existence/status.
- Send and verify OTP with an unauthenticated upstream request, separate from
  the shared superuser SDK. Strip incoming `Authorization`; an existing browser
  session must not authorize the new login. Return auth only after successful
  code verification and an active, verified record check. Check activation
  again on subsequent protected requests/refreshes.
- Enforce server-side resend and attempt limits. The reference uses a 60-second
  resend cooldown, five sends per email per 15 minutes, and five verification
  attempts per challenge per ten minutes, plus IP limits. Return `429` with
  `Retry-After`. Its in-memory limiter assumes one API process; check deployment
  scope before reusing it. Apply upstream timeouts and never log addresses,
  codes, request bodies, or auth tokens from these routes.

In the copied init migration, **replace** the password roster's public
`users.listRule` and `users.viewRule` before saving the collection. Preserve
the shared fields and session-duration configuration. For a new OTP-only app:

```js
users.listRule = null
users.viewRule = null
users.passwordAuth.enabled = false
users.otp.enabled = true
users.otp.duration = 600
users.otp.length = 6
users.otp.emailTemplate.subject = "Your {APP_NAME} sign-in code"
users.otp.emailTemplate.body = "<p>Your sign-in code: <strong>{OTP}</strong></p><p>It expires in 10 minutes and works once.</p>"
```

Omit the public roster endpoint and password UI in this mode. Keep raw user
creation/management behind the API; do not open collection rules for signup.
These settings apply to `users`, not the dashboard's superuser collection. The
reference app retains password auth for guests and older clients; do not copy
that exception into a new OTP-only scaffold. Keep user auth refresh and the
dashboard's authenticated management contract working with the explicit routes.

Verify APIs against the pinned release before generating code:
[PocketBase authentication](https://pocketbase.io/docs/authentication/),
[record OTP endpoints](https://pocketbase.io/docs/api-records/), and
[auth collection options](https://pocketbase.io/docs/api-collections/).

## Acceptance checks

- **Both modes:** the selected method works through the public app origin;
  inactive accounts cannot authenticate/access data; refresh, expiry, logout,
  and account changes preserve the shared session behavior; dashboard login
  remains available independently of the app's sign-in choice.
- **Password:** roster selection and valid/invalid password handling work;
  unselected OTP routes/UI are absent.
- **OTP frontend:** cover email → code → signed in, leading-zero/pasted codes,
  focus, pending/duplicate actions, resend cooldown and challenge replacement,
  changing email, incorrect/expired codes, `429`, and delivery failure/retry.
  Check mobile keyboard behavior and supported light/dark themes.
- **OTP API:** cover the selected provisioning policy, existing/inactive/unknown
  accounts, creation races, expiry/replay, attempt limits, stripped auth headers,
  rejected injected fields, and unchanged session on failed verification.
  Verify real delivery plus successful login against the configured PocketBase
  instance; mocked API success alone does not establish working email sign-in.
