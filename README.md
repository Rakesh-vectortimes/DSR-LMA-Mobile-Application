# DSR & LMA (Flutter)

Mobile app for Diagnostic Study Reports and Lean Maturity Assessments.
Talks to the same REST API as the web app: `{{BASE_URL}}/api/v1`.

This app is DSR + LMA only. It does not use `/5s-audit-*` paths.

## Contract source of truth

Match API shapes from the Angular web repo (`Diagnostic Study Report Frontend`).
Do not invent fields.

| Area | Web reference |
|------|----------------|
| LMA payload + normalize | `src/app/lean-maturity-assessment/utils/lma-api.mapper.ts` |
| LMA CRUD + list/export | `src/app/core/services/lean-maturity-assessment.service.ts` |
| DSR form → payload | `src/app/diagnostic-study/utils/study-form.builder.ts` (`formToStudyPayload`) |
| DSR CRUD + list/export | `src/app/core/services/diagnostic-study.service.ts` |

Flutter mirrors: `lib/features/lma/domain/lma_api_mapper.dart`,
`lib/features/dsr/domain/dsr_api_mapper.dart`.

## MVP scope

| In MVP | On web only (post-MVP on mobile) |
|--------|-----------------------------------|
| Login / session restore | LMA settings (`/sections`, `/grades`, `/lma-questions`) |
| LMA list / create / preview | Company / employee admin |
| DSR list / create / preview | |
| | Export PDF/Word (**next** on mobile) |

Flow: **Login → LMA list/create/preview → DSR list/create/preview**

## Phase status

| Phase | Scope | Status |
|-------|--------|--------|
| 0 | Scaffold, env, theme, routed shell | **Done** |
| 1 | Auth + Dio refresh + session restore | **Done** |
| 2 | Companies + LMA config loaders | **Done** |
| 3 | LMA assessments | **Done** |
| 4 | DSR assessments | **Done** |
| 5 | Export PDF/Word | **Done** (UI present; treat as post-MVP polish) |
| 6 | LMA settings admin | **Web only for MVP** (code kept, route disabled) |

## Run

```bash
flutter pub get
flutter run
```

Prod env:

```bash
flutter run --dart-define=APP_ENV=prod
```

Set URLs in `.env.dev` / `.env.prod` (`API_BASE_URL`, `API_V1_BASE_URL`).

**Live API** (same as 5S Audit Playstore; default in both env files):

```
API_BASE_URL=https://leanapi.vectortimes.com
API_V1_BASE_URL=https://leanapi.vectortimes.com/api/v1
```

Auth and DSR/LMA routes stay under `/api/v1` (e.g. `POST …/api/v1/auth/login`).

**Local backend (optional):** uncomment the localhost blocks in `.env.dev`.
Android emulator → `http://10.0.2.2:8000/api/v1`; desktop / iOS simulator → `http://localhost:8000/api/v1`.

## Auth (Phase 1)

- Tokens in `flutter_secure_storage`
- Dio Bearer interceptor + single-flight refresh on 401
- Splash restores via `GET /auth/me`
- Logout from More (best-effort API + always clear local session)
- LMA settings: use the web app for MVP (mobile route redirects to More)

## Structure

```
lib/
  core/           # config, network, router, theme, storage, permissions
  features/       # auth, home, lma, dsr, more, companies
  shared/         # cross-feature widgets
  main.dart
```

## Conventions

- Response envelope: `{ success, message, data }`
- Auth: Bearer `access_token`; refresh on 401 once; no Bearer on `/auth/login` or `/auth/refresh`
- Report status is an integer for DSR and LMA: `1` Draft, `2` Published, `3` Archived (`submitted` still maps to `2`)
- LMA and DSR share auth + companies; they do not share payloads
- Company is autocomplete; location is a string on the company
