# Legal TODO

Last updated: 2026-07-04

This is not legal advice. It is a project checklist so legal/privacy/release
items are not forgotten.

## Current status

- The app is private dev-only.
- Auth and production Firebase are bypassed for dev.
- Current bundled lessons include `redistribution_permission: not_claimed`.
- `docs/privacy_policy.md` and `docs/privacy_policy.html` still describe Yalla
  English and the old support contact.
- Existing agent rules say not to casually edit legal/privacy text.

## Before any public or wider distribution

- [ ] Replace Yalla English privacy policy with Yalla Arabic policy.
- [ ] Confirm support contact.
- [ ] Confirm whether auth/account deletion exists in the released app.
- [ ] Confirm whether Firebase Analytics is active.
- [ ] Confirm whether Cloudflare R2 or another CDN serves lesson content.
- [ ] Confirm what data is stored locally vs remotely.
- [ ] Confirm content rights for every lesson.
- [ ] Replace `redistribution_permission: not_claimed` with reviewed status.
- [ ] Review app store disclosures if using Play distribution.
- [ ] Review copyright/licensing for images, audio, transcripts, and generated
  translations.

## Content rights checklist

For each lesson:

- source URL or original recording id
- owner/creator
- permission/license status
- whether transcript is original, human-created, auto-generated, or edited
- whether English translation is human-created, machine-generated, or edited
- reviewer
- approved distribution scope

Recommended statuses:

- `private_dev_only`
- `permission_requested`
- `permission_granted`
- `owned_original`
- `licensed`
- `rejected`

Do not treat `not_claimed` as releasable.
