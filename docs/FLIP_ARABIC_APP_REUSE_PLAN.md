# Flip Arabic App Reuse Plan

Last updated: 2026-06-10

## 1. Executive Summary

Yalla English is currently a Flutter Android app for Arabic speakers learning
English. Its primary lesson audio and transcript language is English, with
Arabic translation/explanation support. The current Android package is
`com.yallaenglish.app`, and the current app version is `1.4.1+25`.

The future flip app is a separate app for English speakers learning Arabic,
specifically Modern Standard Arabic / Al-Fusha. Its primary audio and transcript
language should be Arabic, with English translations and learner explanations.

Much of the app skeleton can be reused: course navigation, lesson list, audio
player, sentence timing model, saved words, review quiz structure, local cache,
remote content loading, Firebase-style progress tracking, and release discipline.
The language/content layer must be replaced: Arabic audio, Arabic transcripts,
English translations, Arabic vocabulary data, Arabic tokenization, UI copy,
branding, Firebase project, package identity, signing, store listing, and legal
site.

The biggest risks are Arabic-specific text handling, especially RTL layout,
tokenization, clitics, phrase-level vocabulary, diacritics policy, and avoiding
dialect mixing. The second major risk is content production: timestamps should
be captured during recording/transcription from day one to avoid the historical
timestamp cleanup burden documented for Yalla English content.

## 2. New App Concept

The new app teaches English speakers Al-Fusha Arabic through audio-first,
course-based lessons. Each lesson should center on recorded Arabic audio, an
accurate Arabic transcript, and a clear English translation.

Core learner experience:

- Arabic audio-first lessons.
- Arabic transcript as the primary text.
- English translation as supporting text.
- Clickable Arabic words and phrases.
- Vocabulary panel explaining Arabic for English-speaking learners.
- Saved Arabic words/phrases.
- Review quiz for Arabic vocabulary.
- Progress and listening tracking.
- Course and lesson structure similar to Yalla English.

The app should present Arabic as the language being learned, not as a helper
translation. English should explain meaning, grammar, usage, and learner notes.

## 3. What Stays Mostly the Same

| System | Current file/path area | Reuse level | Notes for Arabic adaptation |
| --- | --- | --- | --- |
| Home/course list | `lib/screens/home/home_screen.dart`, `lib/data/courses_data.dart`, `lib/models/course.dart` | HIGH | Keep the course/list structure, but replace course titles, descriptions, levels, and lesson metadata with Arabic-learning courses. |
| Lesson list | `lib/screens/lessons/lesson_list_screen.dart`, `lib/models/course.dart` | HIGH | Reuse navigation and lesson grouping. Rename lesson type labels if the Arabic app uses different categories. |
| Audio player | `lib/screens/lessons/player_screen.dart`, `lib/providers/audio_provider.dart`, `lib/services/audio_handler.dart` | HIGH | Keep queue, speed, seek, repeat, sleep timer, and background playback concepts. Audio path generation should point to the new Arabic content tree. |
| Sentence transcript player | `lib/screens/lessons/player_screen.dart`, `lib/models/sentence.dart` | MEDIUM | Timing/highlight logic is reusable. Rendering must flip Arabic to primary and English to secondary, with stronger RTL support. |
| Saved words system | `lib/providers/favourites_provider.dart`, `lib/screens/lessons/word_definition_overlay.dart` | MEDIUM | Persistence model is reusable, but saved entries should support Arabic surface forms, lemmas, phrases, and lesson-scoped vocabulary IDs. |
| Review tab / MCQ quiz | `lib/screens/review/`, `lib/services/review_question_builder.dart`, `lib/models/review_question.dart`, `lib/models/quiz_models.dart` | MEDIUM | Quiz flow and history are reusable. Question/answer modes should be redesigned around Arabic prompt to English meaning. |
| Progress/listening tracking | `lib/providers/progress_provider.dart`, `lib/services/firestore_progress_service.dart`, `lib/services/daily_usage_service.dart`, `lib/services/analytics_service.dart` | HIGH conceptually | The model can stay similar, but collection/event names should be reviewed for the new app and new Firebase project. |
| Offline/cache/cloud loading | `lib/providers/download_provider.dart`, `lib/services/audio_cache_service.dart`, `lib/services/content_source_config.dart` | HIGH conceptually | Reuse the remote URL/cache namespace pattern. Use new bucket/path names and avoid mixing production assets. |
| R2 content delivery pattern | `lib/services/content_source_config.dart`, `docs/ASSET_RECOVERY.md` | HIGH conceptually | Use a new R2 bucket or path namespace, separate manifests, and separate checksums. |
| Firebase architecture pattern | `lib/main.dart`, `lib/providers/auth_provider.dart`, `lib/services/firestore_progress_service.dart` | MEDIUM | Auth/progress ideas are reusable. Config, project, package, OAuth clients, and rules must be new/reviewed. |
| General release/runbook process | `docs/RELEASE_RUNBOOK.md`, `docs/STATUS.md`, `reports/` | HIGH conceptually | Follow the same discipline: versioning, validation reports, protected signing, no secret printing, and clear rollback evidence. |

## 4. What Must Be Flipped or Rebuilt

- Language direction: the target language becomes Arabic / Al-Fusha, and English
  becomes the support language.
- UI copy and labels: replace English-learning copy, course titles, onboarding,
  settings text, review labels, privacy/about wording, and app name references.
- Transcript display priority: Arabic first, English second.
- RTL handling: Arabic transcript, vocabulary headwords, examples, and phrase
  cards need correct `TextDirection.rtl`, alignment, wrapping, and punctuation.
- Arabic fonts/rendering: choose fonts that render Arabic clearly on Android,
  including optional diacritics.
- Word tokenization: current English `split(' ')` and punctuation stripping in
  `player_screen.dart` and `word_definition_service.dart` are not enough.
- Clickable word detection: Arabic clitics, attached prepositions/articles, and
  phrase entries require a new lookup strategy.
- Vocabulary lookup: replace `assets/word_definitions.json` with an Arabic
  learner dictionary schema.
- Review quiz prompts/answers: show Arabic words/phrases and ask for English
  meaning first; pronunciation/audio can be added later.
- Course metadata: rebuild `lib/data/courses_data.dart` for Arabic-learning
  courses and lesson types.
- Firebase project/package identity: create a new project and new Android
  package ID. Do not reuse current config blindly.
- Branding/assets/legal site: new app name, icons, Play listing, privacy/account
  deletion URLs, and support/legal pages.

## 5. Arabic Content Pipeline

Recommended workflow for each lesson:

1. Write or approve the Al-Fusha Arabic lesson script.
2. Record Arabic audio from the approved script.
3. Capture sentence timestamps during recording or transcription.
4. Create an accurate Arabic transcript immediately after recording.
5. Translate each Arabic sentence into English.
6. Generate one `content.json` file using the agreed schema.
7. Export normalized `audio.opus`.
8. Validate JSON shape, sentence order, timestamp monotonicity, and audio
   duration coverage.
9. Validate transcript/audio mapping by listening before upload.
10. Upload to R2 or equivalent under the new app namespace.
11. Generate manifests and checksums.
12. QA timing on emulator and physical phone before release.

Important rules:

- Avoid the old timestamp cleanup problems by making timestamps part of the
  original production workflow.
- Preserve source audio, edited audio, source scripts, transcripts, translations,
  and generated JSON.
- Use one standard JSON schema from day one.
- Create manifests/checksums from day one for every JSON/audio pair.
- Do not mix dialect Arabic into app content unless a future product decision
  creates a clearly labeled non-Fusha course.

## 6. Proposed Course JSON Schema for Flip App

Current Yalla English lesson JSON has top-level `lesson_title` and `sentences`,
with sentence keys such as `id`, `english`, `arabic`, `start_time`, and
`end_time`. The flip app should keep the same general shape while making Arabic
the primary text.

Recommended V1 schema:

```json
{
  "schema_version": 1,
  "course_id": "course_01",
  "lesson_id": "lesson_01",
  "lesson_type": "main_story",
  "lesson_title": "At the Market",
  "level": "A1",
  "audio": {
    "path": "assets/courses/course_01/lesson_01/main_story/audio.opus",
    "duration_seconds": 123.45,
    "sha256": "set-during-manifest-generation"
  },
  "sentences": [
    {
      "id": 1,
      "arabic": "ذهبت إلى السوق صباحا.",
      "arabic_diacritized": "ذَهَبْتُ إِلَى السُّوقِ صَبَاحًا.",
      "english": "I went to the market in the morning.",
      "start_time": 0.50,
      "end_time": 3.20,
      "vocabulary": [
        {
          "id": "dhahabtu",
          "surface": "ذهبت",
          "lemma": "ذهب",
          "phrase": false
        },
        {
          "id": "ila_al_suq",
          "surface": "إلى السوق",
          "lemma": "إلى السوق",
          "phrase": true
        }
      ],
      "grammar_notes": [
        {
          "id": "past_first_person",
          "title": "Past tense: I did",
          "note": "The ending ت marks first-person past tense here."
        }
      ]
    }
  ]
}
```

The app should not require diacritics for every sentence in V1, but the schema
should allow them. Vocabulary should support both tokens and phrases, because
Arabic learning often depends on fixed expressions and attached forms.

## 7. Arabic Word Panel Plan

The current word panel is a useful model: a learner taps a word, sees a compact
definition, can expand for detail, save the word, and later review it. The
Arabic version needs a new data model.

Recommended Arabic entry fields:

- Al-Fusha only flag or source policy.
- Stable entry ID.
- Surface form from the lesson.
- Lemma/headword.
- Root when useful.
- Diacritics, optional but supported.
- Pronunciation and/or transliteration.
- Part of speech.
- English meaning.
- Simple learner explanation in English.
- Example sentence in Arabic.
- English example translation.
- Forms, conjugation, broken plural, sound plural, or feminine/masculine forms
  where useful.
- Common phrases/collocations.
- Grammar notes.
- Register/frequency/difficulty.
- Review difficulty.
- Dialect warning or exclusion field, used to prevent dialect mixing.

V1 should prefer high-quality manual entries for each lesson. Fully generated
Arabic dictionary output should go through preview, review, validation, and
reporting before it becomes app content.

## 8. Arabic Tokenization and Clickable Words

Arabic clickable text has technical risks that English does not:

- Clitics and prefixes, such as conjunctions, prepositions, and future markers.
- Attached articles, especially `ال`.
- Attached pronoun suffixes.
- Optional diacritics and text with no diacritics.
- Arabic and Latin punctuation.
- Phrase-level vocabulary.
- Roots vs lemmas vs surface forms.
- Proper nouns.
- Classical- or Quranic-looking words that may not fit modern standard usage.

Recommended V1:

- Use phrase-aware lookup before single-token lookup.
- Match exact surface forms from the lesson.
- Match normalized forms after removing tatweel, normalizing alef/hamza forms
  if the product chooses that policy, and optionally stripping diacritics.
- Maintain manual vocabulary entries per lesson at first.
- Store stable vocabulary IDs in `content.json` instead of depending only on
  automatic text splitting.
- Avoid fully automatic Arabic morphology in V1 unless a real content scale
  problem proves it is needed.

This is the key area where the current English implementation should inspire
the UX but not be copied directly.

## 9. Review Quiz Adaptation

The Arabic review quiz should start with the simplest useful direction:

- Show an Arabic word or phrase.
- Ask for the English meaning.
- Optionally include audio pronunciation later.
- Quiz on saved Arabic words and phrases.
- Support phrase cards, not only single-word cards.
- Use difficulty levels appropriate for Arabic learners, not English CEFR data
  copied from the current dictionary.
- Build future random quiz generation from validated Arabic entries.
- Avoid mixing dialect and Al-Fusha in prompts or answer choices.

The existing MCQ flow, answer selection, history, saved batches, and summary UI
can be reused conceptually. The answer builder should be redesigned so
distractors come from Arabic entries with compatible difficulty and part of
speech.

## 10. UI/UX and RTL Plan

RTL is needed anywhere Arabic is primary content:

- Arabic transcript lines.
- Arabic vocabulary headwords.
- Arabic example sentences.
- Arabic phrase cards.
- Arabic search/lookup displays if added.
- Review prompts that show Arabic.

English translation and explanation should remain LTR. Mixed Arabic/English
layouts should avoid forcing the whole screen into one direction when only a
specific text block needs RTL.

Design requirements:

- Arabic transcript aligned right or visually prioritized with clear wrapping.
- English translation aligned left or visually secondary.
- Font selection tested on real Android devices.
- Tap targets large enough around Arabic words/phrases.
- Mixed-script punctuation checked manually.
- Optional diacritics rendered legibly.
- Mobile-first layouts for narrow screens.
- Accessibility/readability checked with larger font settings.

## 11. Firebase/Auth/Analytics Reuse

Reusable conceptually:

- Email/password and Google sign-in flow.
- Account-linked progress.
- Local-first progress with cloud backup.
- Account deletion pattern.
- Usage/listening analytics events.

Must be new or reviewed for the new app:

- Firebase project.
- Android package ID.
- Android Firebase app registration.
- Google Sign-In OAuth clients.
- Firestore rules and indexes.
- Analytics event names and parameters.
- Privacy/account deletion wording and URLs.

Do not reuse current Firebase config blindly. The current files
`android/app/google-services.json` and `lib/firebase_options.dart` are protected
for Yalla English and should not be copied into a new production app without an
explicit migration decision. The progress schema can be similar, but names
should reflect the Arabic app domain.

## 12. R2 / Audio Hosting Reuse

The current R2-style content delivery pattern can be reused, but production
assets must be separate.

Recommended strategy:

- New bucket or clearly separate path namespace for the Arabic app.
- Paths like `arabic-fusha/courses/course_01/lesson_01/main_story/`.
- One `content.json` and one `audio.opus` per lesson/type.
- A manifest listing every JSON/audio pair.
- SHA-256 checksums for JSON and audio.
- Duration and sentence timestamp validation in the manifest or report.
- Rollback by preserving previous manifests and uploaded object versions.
- No mixing of Yalla English production paths with Arabic app production paths.

## 13. What Not To Copy Blindly

Do not blindly copy:

- Android package ID `com.yallaenglish.app`.
- Firebase config files.
- Signing keys or keystores.
- Play Store listing/assets.
- Privacy policy/account deletion URLs.
- Old English course content.
- `assets/word_definitions.json` as the Arabic dictionary.
- Arabic translations that were written for Arabic speakers learning English.
- Hardcoded app names.
- R2 bucket paths or public base URL.
- Analytics collection/event names if they are app-specific.
- Legal/support site deployment.

The flip app should be a new app that reuses architecture, not a renamed build
of the current Yalla English production identity.

## 14. Recommended New Project Bootstrap Steps

1. Create a new folder outside the current repo.
2. Copy the current repo as the starting base.
3. Rename app identity and package.
4. Create a new Firebase project.
5. Register the new Android app with the new package ID.
6. Set up new signing carefully and keep signing material out of Git.
7. Strip or replace English course content.
8. Design and freeze the Arabic content schema.
9. Build one pilot course/lesson.
10. Record Arabic audio with timestamps.
11. Create transcript/translation JSON.
12. Build Arabic word panel V1.
13. QA on emulator and physical phone.
14. Only then scale courses.

## 15. Files/Modules To Inspect First When Starting

| File/folder | Why it matters | Reuse value | Caution |
| --- | --- | --- | --- |
| `lib/screens/lessons/player_screen.dart` | Main audio/transcript UI, sentence highlighting, clickable words, repeat mode | HIGH | English is currently primary and clickable; Arabic is secondary translation. |
| `lib/models/sentence.dart` | Defines current sentence JSON parsing | MEDIUM | Current field names assume `english` plus `arabic`; flip schema may need explicit primary/translation fields. |
| `lib/models/course.dart` | Course, lesson, and lesson type model | HIGH | Lesson type labels and asset folder conventions may need renaming. |
| `lib/data/courses_data.dart` | Hardcoded course and lesson catalog | HIGH | Replace all English course metadata. |
| `lib/screens/lessons/word_definition_overlay.dart` | Learner vocabulary panel UI | MEDIUM | Current panel fields explain English words to Arabic speakers. |
| `lib/services/word_definition_service.dart` | Dictionary loading and lookup | LOW/MEDIUM | English normalization and suffix stripping do not fit Arabic. |
| `lib/providers/favourites_provider.dart` | Saved lessons and saved words persistence | HIGH | Saved word keys should support Arabic entry IDs, phrases, and clicked surface forms. |
| `lib/screens/review/` | MCQ review screens and summary | MEDIUM/HIGH | Quiz direction and labels must change. |
| `lib/services/review_question_builder.dart` | Builds MCQ questions and distractors | MEDIUM | Current answer modes use English definition or Arabic translation fields. |
| `lib/providers/audio_provider.dart` | Audio state, sentence index, seek, speed, looping | HIGH | Timestamp quality is critical for Arabic lesson QA. |
| `lib/services/audio_handler.dart` | Queue loading, JSON/audio fetch, background playback | HIGH | Confirm new content path and cache behavior. |
| `lib/services/audio_cache_service.dart` | Remote audio caching | HIGH | Use a separate cache namespace for the new app. |
| `lib/services/content_source_config.dart` | Remote content base URL and debug overrides | MEDIUM | Replace current production content base and local override naming. |
| `lib/services/firestore_progress_service.dart` | Cloud progress/profile storage | MEDIUM | Use a new Firebase project and reviewed collection names. |
| `lib/providers/progress_provider.dart` | Local progress and cloud backup integration | HIGH | Reuse conceptually, but test new schema names. |
| `lib/main.dart` | Provider, Firebase, audio service initialization | MEDIUM | Requires new Firebase options and app identity. |
| `lib/core/app_colors.dart` and theme providers | Visual theme | MEDIUM | New brand should not inherit Yalla English blindly. |
| `assets/courses/` | Current local course JSON editing copy | LOW for content, HIGH for path pattern | Do not modify existing content; use only as structural reference. |
| `assets/word_definitions.json` | Current bundled dictionary structure | LOW for content, MEDIUM for panel inspiration | Do not reuse English entries as Arabic learner data. |
| `pubspec.yaml` | App name, version, assets, dependencies | MEDIUM | New app needs new package metadata and asset declarations. |
| `android/app/build.gradle.kts` | Android namespace/application ID/version wiring | MEDIUM | New package ID required; do not change current app during planning. |
| `docs/RELEASE_RUNBOOK.md` | Release discipline and safety gates | HIGH conceptually | Existing package/signing rules apply to Yalla English, not the new app. |

## 16. Open Questions Before Building

- What is the app name?
- What is the starting learner level: A1, A2, B1, or another target?
- Will audio use male voice, female voice, or both?
- Will Arabic include full tashkeel, partial tashkeel, no tashkeel, or a toggle?
- How much grammar should appear in the word panel?
- Should vocabulary per lesson be manual, automatic, or manual first with
  assisted suggestions?
- What R2 bucket/path naming should be used?
- What Firebase project name should be used?
- What Android package ID should be used?
- Is guest mode needed?
- What is the initial review quiz scope: saved words only, random practice, or
  both?
- Should pronunciation audio be generated per word, clipped from lessons, or
  deferred?
- Should the first course be stories, survival phrases, grammar-driven lessons,
  or mixed?

## 17. Quick Prompt For Future Claude/Codex

Use this prompt when starting the Arabic flip project:

```text
I want to build the Arabic-flip app from Yalla English. Read
docs/FLIP_ARABIC_APP_REUSE_PLAN.md first, then inspect README.md, PROJECT.md,
AGENTS.md, docs/ARCHITECTURE.md, docs/STATUS.md, docs/RELEASE_RUNBOOK.md,
docs/ASSET_RECOVERY.md, docs/REPORT_INDEX.md, lib/, lib/screens/,
lib/services/, lib/data/, assets/courses/ structure only, and
assets/word_definitions.json structure only. This is a new separate app for
English speakers learning Al-Fusha Arabic. Do not modify the current Yalla
English production app, Firebase config, signing, Play, R2, assets, audio,
course JSON, or secrets unless I explicitly approve that specific work.
```
