# Nagar Shield 360 — shared workflow test and hackathon recording plan

## Product contract

- **Flutter:** citizen reporting and owned status, official work, survey capture, local offline demo.
- **Web:** public landing and official sign-in only. No citizen form, citizen tracking, signup, or public operational data on the web.
- **Shared Supabase:** a mobile report becomes an observation; an authorized official reviews it; only then does an incident exist. A named worker acts on a task; a supervisor or head approves evidence. Both official clients show the same record and status after refresh.
- **Honest demo boundary:** preset detections, scores, map points and seeded survey media are simulated. Mobile public and survey submissions are test records. Do not call a manual annotation AI inference or a test photo proof of municipal work.

## P0 preparation — do before any rehearsal

1. Work from `NagarShield-360` and `NagarShield App` in this workspace. Record the exact commits/build versions and the target Supabase project reference in private rehearsal notes. Never put keys or passwords in the recording.
2. For a **fresh** database, apply web `202610130001_prototype.sql`, then `202610130002_reset_hotfix.sql`, then mobile `mobile_extension.sql` and `mobile_extension_2.sql`, then web `202610140001_survey_demo.sql` and `202610140002_bangla_copy.sql`. The web survey migration now extends the mobile schema. Check migration history before applying to a populated project; do not replay an already applied migration.
3. Keep Email signup and anonymous Auth disabled. Provision the official and three controlled mobile citizen demo accounts using the local, ignored account files. The A/B/C citizen identities are shared demo identities: two devices choosing the same letter share history. Use different letters for isolation proof.
4. Build the web as a server application and the same universal Android APK for both phones. Point web and Flutter at the **same** Supabase project. The web needs only the publishable key; service role credentials stay in local provisioning scripts. Use a clean dedicated showcase project where possible: older synthetic `DEMO TEST` and `hello` reports currently clutter the configured project's dashboard and weaken the recording.
5. Use two phones or one phone plus a clean second installation for citizen A/B. Prepare two non-identifying drain photos, one before and one after. Use separate browser profiles for executive, supervisor and field roles. Set browser zoom to 100%, desktop viewport near 1366×768, and phone portrait near 390×844.
6. Run the local gates below. On the shared project, run read-only `check_showcase_data.mjs`, `check_official_views.mjs` and `check_shared_contract.mjs`. The last check must pass before recording; as of 14 October 2026, the configured project lacks `survey_missions.department_id`, so apply the pending web survey and copy migrations after reviewing its migration history, then rerun the check. Reapply the updated idempotent `mobile_extension_2.sql` to install the preset-evidence guard if that project used an older copy. Run mutating live checks only in a disposable rehearsal dataset: they create records. If provisioning or reset is needed, do it **before** creating the citizen report and confirm existing test reports will be retained.

## Local gates and required evidence

| Gate | Command/location | Pass evidence |
| --- | --- | --- |
| Shared schema and permissions | `npm run test:migration` in web | Clean migration order, mobile citizen ownership, web review, role scope, reset preservation, and state transitions pass. |
| Web compilation | `npm run typecheck` and `npm run build` in web | Both exit 0. |
| Unified operations rehearsal | Compare SHA-256 of both `operations-seed.json` files, run the mobile `operations_lab_test.dart`, and walk through private web `/operations` at desktop and phone widths | Four cases match; map trace and blind-spot inspection work; reviewed evidence changes an explained score; missing resources block the affected assignment; survey completion requires its permission checkbox. |
| Flutter static and widget checks | `flutter analyze` and `flutter test` in app | Both exit 0; save summary, not secrets. |
| Mobile SQL retry and ownership | `node scripts/check_mobile_extension.mjs` in app | Extension, ownership, idempotency and reset pass. |
| Browser layout | `npm run test:layout` and `npm run test:official-layout` with local server | Landing and official screens render at desktop and phone sizes with no horizontal overflow. |
| Web access boundary | `npm run test:web-boundary` with local server | Signed-out operational pages and APIs are blocked; citizen A cannot sign in to web official pages. |
| Live preflight | `node scripts/check_showcase_data.mjs` and `node scripts/check_official_views.mjs` in app | Shared roles, views, task data and media are readable. |
| Shared deployment contract | `node scripts/check_shared_contract.mjs` in app | Web survey columns exist; citizen A/B status histories do not overlap and citizen accounts see no official profile. |

## P0 end-to-end acceptance: one report code across both clients

Use a unique title such as `বাজার সড়কের ড্রেন বন্ধ — প্রদর্শনী ১৪ অক্টোবর`. Write the generated `NS-P-...` code on the shot list. Keep that exact code visible at each handoff.

| # | Actor / screen | Action | Required result and capture |
| --- | --- | --- | --- |
| 1 | Citizen A, Flutter | Choose A; create a drain report with description, area, approximate coordinates and before photo. Review privacy preview and submit. | One `NS-P-...` code in **আমার প্রতিবেদন**, status **কর্মকর্তার যাচাই বাকি**. No incident/task exists yet. |
| 2 | Citizen B, Flutter | Choose B and inspect owned history. | A's code is absent. B cannot fetch A's observation or media. |
| 3 | Executive, web **ঘটনা কেন্দ্র** | Search A's code in review queue, inspect text/photo, add a review note and verify. | Same code becomes an incident; timeline shows official verification. The review queue drops by one. |
| 4 | Executive, web incident | Assign drainage department, `drainage-a`, named drainage worker, with an instruction. | Incident and one task show **কাজ দেওয়া হয়েছে**; worker and instruction match on web and Flutter after refresh. |
| 5 | Drainage worker, Flutter **আমার কাজ** | Accept, start, then upload after photo and a completion note. | Status goes accepted → in progress → **কাজ শেষে যাচাই বাকি**. Before and after media display in authorized web incident view. |
| 6 | Drainage supervisor, web | Compare before/after and approve. | Task and incident become **কাজ শেষ, অনুমোদিত**; worker cannot approve own task. Audit trail names the steps. |
| 7 | Citizen A, Flutter | Refresh owned reports. | Same code shows approved completion; B still does not see it. |
| 8 | Executive, web and Flutter reports | Refresh and inspect count, department chart/list, map marker, incident timeline and CSV. | Resolved count rises by one from recorded baseline; CSV row matches the visible incident and status. |

**Pass gate:** all eight steps succeed on the same code, with no manual database edit. A page looking right is insufficient if a server permission or media request fails.

## P0 access and privacy matrix

| Test identity | Direct access/action to attempt | Expected server result |
| --- | --- | --- |
| Signed-out browser | `/dashboard`, `/incidents`, copied incident URL, `/api/reports/export`, `/api/media/scenarios/drain.svg` | No official content, CSV or bytes; sign-in or unauthorized response. Landing remains visible. |
| Citizen A web sign-in | Try the A demo credentials in web official sign-in | Denied as a non-official account. No operational page. |
| Citizen B mobile | Open A's report/media through another identity | No A history or private media. |
| Waste worker | Open drainage task/incident ID and submit action | Hidden in list and rejected by RLS/RPC direct-link check. |
| Drainage worker | Approve their own completion | Rejected; only authorized manager can review. |
| Supervisor | Open out-of-team incident and task IDs | No details, media or action permission. |
| Survey operator | Open dashboard/task URLs and attempt task change | Survey scope only; no task action. |

Also test wrong password, expired session, a stale approval after another manager acts, and a direct RPC with a mismatched department/team. Verify status remains unchanged after each rejected action.

## P1 resilience and completeness

1. **Offline intake:** save a citizen draft with image, restart, submit in airplane mode, reconnect and retry twice. Require one remote report, one code and preserved image.
2. **Offline staff:** queue accept/start or evidence, restart, reconnect, and inspect sync queue. Require one transition; conflicts appear as rejected actions with a readable reason.
3. **Rework:** use a separate report. Supervisor returns the submitted task with a reason; worker sends revised evidence; manager approves. Verify timeline and citizen status.
4. **Multiple departments:** on a separate scenario incident assign drainage and waste. Approve drainage first; incident must stay open until waste is approved. Reopen a completed task and check aggregate status.
5. **Survey:** record one GapScan and one drone observation in Flutter, with source, site/time, permission reference where relevant, manual annotation and private media. Find them on web **জরিপ** and in authorized review queue. State that no drone flight or model inference occurs.
6. **Media and localization:** all six presets, two videos, imported image/MP4, manual box/polygon/timed annotations; check simulated labels. Repeat critical labels and forms in Bangla and English, at 390×844 and 320×700. Deny camera/location permission and use gallery/manual coordinates.
7. **Reset isolation:** with a citizen report and a real mobile survey in place, use web demo reset. Seeded scenarios return to baseline; citizen/survey test records and their incident/task history remain. Never reset during the main recording.
8. **Unified operations rehearsal:** in both web `/operations` and mobile **City Operations**, select the market case. Trace a connected asset path, choose a point and open its suggested task. Review CCTV age, blind spot and confidence; accept or reject the evidence and show the score explanation change. Mark sample flight permission before completing the sample survey. Remove a required resource and show that the affected assignment is blocked while an alternative plan appears. Record a partner blocker, preview the citizen update, finish the submitted work and schedule a repeat check. Use the alley case for building-gap and roof-garden inspections without claiming larvae from imagery; the footpath case for obstruction moving to the next road; and the clinic-road case for sewage, blocked emergency access, and crash/fire responder handoff. Explain that acknowledgements, clearance, maps, detections and assignments here are seeded local rehearsal data.

## Screen recording: 7 to 8 minutes

Record at 1080p/30 fps if available; use a desktop capture for web and a mirrored phone capture for Flutter. Keep cursor/taps visible, notifications off, and credentials hidden. Use a short title card with team/project name and the explicit scope: “citizen mobile + officials web/mobile, shared workflow.” Speak naturally in Bangla and add concise English subtitles if the judges are not Bangla speakers. Keep the report code and source label legible on each transition.

| Time | Shot | Claim to say and evidence to show |
| --- | --- | --- |
| 0:00–0:30 | Landing on both clients | Explain the problem and roles. Show the web has official sign-in only; mobile has citizen reporting. |
| 0:30–1:25 | Citizen A Flutter | Photo, approximate location, privacy preview, submit and code. Say that official review is required. |
| 1:25–2:15 | Executive web review | Same code, source “mobile citizen report”, private before photo, review note, verify. Pause on new incident. |
| 2:15–2:55 | Executive assignment/map | Named worker, department/team, instruction and location marker. |
| 2:55–4:05 | Worker Flutter | Accept, start, after photo, completion note. Show cross-device update after refresh. |
| 4:05–4:55 | Supervisor web | Compare before/after, approve, show audit timeline. |
| 4:55–5:45 | Citizen A and B Flutter | A sees approved status; B's history does not contain A's code. |
| 5:45–6:35 | Web reports and CSV | Resolved count, department view and same-code CSV row. |
| 6:35–7:20 | Survey or analysis cutaway | Show one GapScan and a simulated preset; explicitly distinguish manual annotation and simulated score from live AI. |
| 7:20–7:50 | Signed-out browser access proof / close | Protected URL blocked, then one-slide recap: shared traceable workflow, role scope, offline retry, honest prototype limits. |

Capture sign-ins separately with recording paused. Prefer a continuous workflow take; if cuts are needed, use a small transition caption with role and code. Do not splice different report codes into one story. Keep an unedited full rehearsal as backup and export a short version only after all gates pass.

### Optional two-minute product-vision cutaway

If the judging format permits a longer demo or a separate clip, show the unified operations screen after the real shared workflow. Spend about 20 seconds tracing the drain/footpath/sewer map and camera blind area, 20 seconds on approved drone survey and roof/gap access, 20 seconds reviewing CCTV evidence and the explainable priority, 25 seconds on equipment constraints and partner blockers, 25 seconds switching crash/fire leads and showing responder acknowledgement versus scene clearance, and 10 seconds on repeat checks. Put **“seeded planning prototype”** on screen throughout. This demonstrates the next product direction without implying live footage, drone flight, AI inference or real emergency dispatch is connected.

## Submission package and stop conditions

Deliver the APK, web URL, 7–8 minute video, a one-page architecture diagram, test result log, role matrix and a short limitations slide. Put the exact commit/build and recording date on the final slide. If the hackathon publishes a rubric, map each rubric point to a timestamp and test proof before submission.

Stop recording if migration, sign-in, private media, role isolation, end-to-end status or reset preservation fails. Fix and rerun that gate before producing the final take. A passing local build does not establish that the deployed web URL and shared Supabase project work together; repeat the P0 chain against the actual submission environment.
