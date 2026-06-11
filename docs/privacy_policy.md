# Yalla English Privacy Policy

**Effective date:** June 8, 2026

**Support contact:** yallaenglish.app@gmail.com

## Overview

Yalla English is an authenticated English-learning app. It supports
email/password accounts and Google sign-in. This policy explains what
information the app processes, why it is used, where it is stored, and how a
user can delete an account.

## Information We Collect

### Account information

- Email/password sign-in uses the email address supplied by the user.
- Google sign-in may provide an email address, display name, profile image,
  provider identifier, and Firebase user identifier.
- Firebase Authentication processes sign-in credentials and account status.

### Learning and profile information

The current Firestore schema stores account-linked data under the signed-in
user's Firebase UID. This may include:

- lesson progress and completion;
- total and daily app-use and listening minutes;
- course listening totals, streaks, and daily goal;
- favorite lessons and saved words;
- compact daily usage totals and feature activity counts;
- onboarding completion and profile first name.

### Review and quiz information

Vocabulary quiz batches and history, missed-word review state, grammar topic
progress, and weak grammar tags are currently stored locally on the device.
Saved words are also synchronized through the account's Firestore progress
document.

### Local storage and caches

The app uses device storage for settings, theme and playback preferences,
progress, favorites, saved words, review history, grammar practice,
onboarding state, cached lesson text, and downloaded lesson audio.

### Diagnostics

Yalla English uses Firebase Analytics for aggregate app and feature usage.
Firebase Analytics may automatically collect app usage events, such as app
opens and sessions, along with technical information about the app and device.
Firebase and Google Analytics may use pseudonymous app-instance or device
identifiers to measure usage and retention.

The app's custom Analytics events include rounded app/listening time, lesson
and practice activity counts, question counts, score ranges, and listening
milestones. These custom events do not include names, email addresses, Firebase
UIDs, saved-word text, clicked-word text, quiz question content, grammar
prompts, sentence text, transcripts, or audio.

The app does not include an advertising SDK or dedicated crash-reporting SDK.
Android, Firebase, Google Sign-In, and content delivery providers may still
generate limited operational, security, or error logs. Developer authentication
diagnostics are limited to debug builds.

### Content delivery

Course audio and lesson content are delivered through Cloudflare R2 or its
content delivery network. The delivery service may process standard network
information such as IP address, request time, requested file, and device or
browser headers.

## How Information Is Used

Information is used to:

- authenticate and secure accounts;
- synchronize and restore learning progress;
- provide favorites, saved words, review, and quiz features;
- deliver lesson content and offline downloads;
- maintain app settings and performance;
- troubleshoot errors and protect the service.

Yalla English does not sell personal information.

## Service Providers

The app currently relies on:

- Google Firebase Authentication for account access;
- Google Cloud Firestore for account-linked learning data;
- Google Firebase Analytics for aggregate app and feature usage;
- Google Sign-In for optional Google authentication;
- Cloudflare R2/content delivery for lesson audio and content.

Each provider processes information under its own terms and privacy practices.

## Data Retention

Account-linked data is retained while an account is active or as needed to
provide and secure the service. Local preferences and cached content remain on
the device until cleared, the account deletion flow is completed, or the app
is uninstalled.

## Account and Data Deletion

Authenticated users can open **Settings > Account > Delete Account**. The flow
requires explicit confirmation and recent authentication. For the current app
schema, it deletes:

- documents under `users/{currentUid}/data/*` in Firestore;
- the current Firebase Authentication user;
- local app preferences and account-linked learning/review data;
- cached and downloaded lesson audio/text on that device.

The client is restricted to the currently authenticated UID by both app logic
and Firestore security rules. No Firebase Admin credentials are used in the
app.

## Security

Reasonable technical safeguards are used, including authenticated access and
UID-scoped Firestore rules. No internet transmission or storage system is
completely secure.

## Changes to This Policy

This policy may be updated when app behavior, service providers, or legal
requirements change. The effective date should be updated when a revised
policy is published.

## Contact

Privacy questions or account-deletion support:
yallaenglish.app@gmail.com
