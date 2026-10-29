# NagarShield 360 mobile

Flutter client for the existing NagarShield 360 Supabase project. Flutter code, mobile SQL extension, demo media, and test scripts live in this directory. The Next.js web project remains in its own directory.

## Code map

- lib/app_config.dart: build configuration.
- lib/main.dart: startup.
- lib/nagar_repository.dart: Supabase calls, SQLite public draft and report outbox, profile cache, and local demo persistence.
- lib/staff_outbox.dart: durable official actions and task evidence with idempotent retries.
- lib/demo_flow.dart: local presentation state machine.
- lib/ui/app_shell.dart: navigation and Bangla/English selection.
- lib/ui/landing_page.dart: web-inspired system overview and public, official, and offline-demo entry paths.
- lib/ui/public_page.dart: public reporting, photo privacy preview, and owned status.
- lib/ui/sign_in_page.dart: official account sign in.
- lib/ui/local_demo_page.dart: offline role chain.
- lib/ui/official_pages.dart: role-aware navigation, incident review, map, and governance.
- lib/ui/operations_lab.dart: local, bilingual connected-operations rehearsal from shared dummy seed; also available from the offline Local Demo entry.
- lib/ui/operations_map.dart: interactive schematic ward/drain map, asset selection and sample drone survey route.
- lib/ui/official_overview.dart, official_task_list.dart, official_report_view.dart: shared-data dashboard, assigned work, in-app assignment notices, and reports. The field task view checks for new work every 12 seconds while open; this is not a phone push notification.
- lib/ui/incident_detail.dart, observation_review_card.dart, private_evidence_preview.dart, workflow_labels.dart: named assignment, evidence, review, audit, and Bangla/English workflow labels.
- lib/ui/public_status_card.dart: citizen report progress.
- lib/ui/media_studio.dart, annotation_editor.dart, and preset_media.dart: simulated presets, playback, and locally saved imported media with normalized manual boxes and video time ranges.
- lib/ui/survey_page.dart and survey_annotation_editor.dart: drone and GapScan observation entry with normalized image polygons and timed video boxes.
- lib/ui/staff_queue_page.dart: queued and rejected official work.
- assets/presets: mobile copies of the six web preset illustrations and two clips.
- assets/operations-seed.json: the same four illustrative cases as the official web operations workspace.
- supabase/mobile_extension.sql: additive shared backend migration.
- supabase/mobile_extension_2.sql: idempotent staff action receipts and evidence retries.
- SHOWCASE_TEST_PLAN.md: mobile-led complaint-to-completion run sheet.
- INTEGRATION_TEST_AND_RECORDING_PLAN.md: canonical shared-client acceptance and hackathon recording plan.

## Supabase and demo identities

For a fresh shared project, apply the web base and reset hotfix, both app SQL extensions, then the web survey, Bangla copy, and marked-footage assignment migrations. The current shared demo project already received `NagarShield-360/supabase/migrations/202610290001_marked_footage_assignment.sql` on 29 October 2026. Do not rerun it, the base migration, or reset the demo data. The combined local migration test exercises this order.

The existing web migrations and both app SQL extensions have been applied to the shared project. The project currently has anonymous Auth disabled. For this prototype, three public demo Auth accounts (A, B, C) are provisioned. There is **one app build** for all devices. On first entry to the public form, choose A, B, or C for that installation; choose different letters on different test phones. There is no public password form. A selected letter is stored on the phone and cannot be changed through the app. Anyone who chooses the same letter shares that demo account and report history. This is for controlled demonstration only, not private public distribution.

Public URL/key and demo account passwords are in ignored config/*.local.json files. The showcase APK contains the three dummy public account credentials to support the in-app letter choice. The service role key is only used by the server-side provisioning script and is never included in a Flutter build. To rebuild the local config, run node scripts/prepare_public_demo.mjs after provisioning.

Run on a device:

    flutter pub get
    flutter run --dart-define-from-file=config/showcase.local.json

Build the single release app, split only by Android ABI:

    powershell -File scripts/build_public_demo_apks.ps1

The script runs `flutter build apk --split-per-abi` once and also produces a universal APK. Install **the same** `dist/nagarshield-showcase-universal.apk` on both test devices. Choose A on the first phone and B on the second. The `arm64-v8a`, `armeabi-v7a`, and `x86_64` files are smaller builds of the same app for specific processors.

The output APKs are in dist/. A build without Supabase defines still runs the isolated local presentation scenario.

## Checks

    flutter analyze
    flutter test
    node scripts/check_mobile_extension.mjs
    node scripts/check_live.mjs
    node scripts/check_live_flow.mjs
    node scripts/check_live_survey.mjs
    node scripts/check_live_retry.mjs
    node scripts/check_live_evidence_retry.mjs
    node scripts/check_live_intake_retry.mjs
    node scripts/check_all_demo_logins.mjs
    node scripts/check_showcase_data.mjs
    node scripts/check_official_views.mjs
    node scripts/check_shared_contract.mjs

`.github/workflows/ios.yml` runs the iOS build on a macOS GitHub Actions runner after a push or manual dispatch. It cannot be executed on this Windows machine.

The live checks write clearly named synthetic records into the shared project. The local SQL check reads the baseline migrations and PGlite from ../NagarShield-360; set NAGAR_WEB_DIR for another web checkout. It does not write to that checkout. iOS builds require a macOS runner.

## Scope and limits

The City Operations screen demonstrates four connected cases covering waste, drains, building gaps, roof gardens, footpath recurrence, sewage overflow and emergency access. It includes an asset connection trace, camera blind area, permission-gated sample drone route, reviewed footage, explainable priority, a resource-blocked task with an alternate plan, partner acknowledgements and escalation, a citizen-update preview, crash/fire responder handoff, and repeat-issue watch. All controls on that screen use temporary local state; they do not write to Supabase or message or control cameras, drones, city teams or emergency units. For a no-login presentation, open **Local Demo → City Operations**. The signed-in official screen uses the same seed. Real reports and assignments remain in the existing shared incident/task flow. The canonical [unified engineering roadmap](https://github.com/abdullahshahporan/NagarShield-360/blob/master/docs/UNIFIED_CITY_OPERATIONS_ROADMAP.md) defines the next data contract, stakeholder decisions and pilot gates.

Public form drafts, selected photos, queued reports, and official actions persist on device. Reports and actions retry after launch, resume, and manual refresh. Rejected official actions appear in Sync queue for review. Supabase is authoritative after submission. Officials review public and survey observations before incidents exist. Detection overlays and scores are simulated; imported images support manual boxes and polygons, and MP4 supports timed boxes. Drone and GapScan record observations but do not control hardware or run AI inference. The local presentation scenario has separate SQLite state; Reset Demo affects only that state. The live API workflow has been tested; physical two-device UI rehearsal and iOS CI still need to be run.
