# Pika — iOS Take-Home

A SwiftUI app that walks a new user from auth → selfie capture → guided voice reading → a shareable AI ID card. Built against the Figma mocks, with the gaps filled in by judgment calls documented below.

## Flow at a glance

1. **Landing / Auth** — phone (primary), Google, or email. The phone flow is fully wired; Google/email are stubbed at the seam so they create or look up a user the same way (see [ContentView.swift:51](Pika/Pika/Components/Landing%20page/ContentView.swift:51)).
2. **Resume-aware routing** — on continue, `UserRepository.findOrCreateUser` looks up the identity in Core Data and `nextStep(for:)` decides which onboarding step to drop the user into. A returning user picks up exactly where they left off ([UserRepository.swift:51](Pika/Pika/Data/Repository/UserRepository.swift:51)).
3. **Photo step** — selfie capture via `AVCaptureSession`, JPEG persisted on the `User` row.
4. **Voice step** — user reads a fixed paragraph. We run `SFSpeechRecognizer` against the live mic buffer and match the partial transcript to the paragraph with a tolerant matcher (see *Voice matching* below). When the matcher reports the paragraph complete, the record button flips to a checkmark.
5. **Complete step** — renders the ID card from the user's saved selfie + metadata, with `ShareLink` for Messages / Save to Camera Roll. Dismissing returns to the landing page, where another profile can be created.

## Architecture

**MVVM with a thin repository layer.** The split is:

```
Views (SwiftUI)        →  dumb, render @Published state, send intents to the store
Stores (@MainActor)    →  per-screen view models; orchestrate services + repository
Services               →  AudioRecorder, CameraController — own AV/Speech machinery
Repository             →  UserRepository — only thing that touches Core Data
Entity                 →  User (NSManagedObject)
DataAccess             →  PersistenceController (Core Data stack)
```

Notable seams:

- **`UserRepository` is the only Core Data caller.** Views and stores never see `NSManagedObjectContext` outside of `ContentView` wiring. Swap Core Data for a server-backed store and the surface area to change is one file.
- **`OnboardingStore` owns the state machine** (`photo → voice → complete`). The view just switches on `currentStep`. Back-button policy lives in `goBack()`, not in views.
- **`CompleteStepStore` has two inits** — one that loads from the repo by `userId`, one that takes a `CompleteStepProfile` directly. The second is for previews and for a future server response that already carries the profile; the view doesn't know which path it's on.
- **`AudioRecorder` is plain (non-`ObservableObject`)** and reports out via closures. The store owns `@Published` state. Keeping the service free of SwiftUI lets it be reused in another shell (UIKit, tests) without ceremony.
- **`AuthActions` is a private `EnvironmentKey`** in `ContentView` so the auth panel's subviews don't need a chain of bindings. Small thing, but it keeps the panel readable.

## Design / engineering tradeoffs

### 1. Core Data as the "API" today
The brief says "architect for a backend that lands later." I took that literally: today `UserRepository` is the source of truth, but its method shapes (`findOrCreateUser`, `savePhoto`, `saveAudio`, `fetchUser(userId:)`) are exactly the shapes a network client would expose. When the backend lands, `UserRepository` becomes a protocol with two implementations (local cache + remote) and nothing above it changes. I chose this over building a fake `APIClient` now because (a) it ships a working app today, (b) it doesn't bake in HTTP assumptions the real API may not match, and (c) Core Data already gives us free resume-where-you-left-off across cold launches — which the design implicitly requires.

### 2. Phone-first auth, stubbed providers behind the same seam
All three auth buttons funnel through `openOnboarding(phoneNumber:email:)`. Google/email don't ask for credentials — they hand a synthetic identity to the same repo call. This means the auth UX, the resume logic, and the rest of the flow are all real for any provider you wire up; only the credential-collection sheet is missing. I'd rather ship one identity path end-to-end than three half-built ones.

### 3. Tolerant voice matching instead of strict transcription
A strict transcript compare would strand users on mispronunciations, ASR drops, or homophones — the demo would constantly feel broken. `ReadingProgressMatcher` ([ReadingProgressMatcher.swift](Pika/Pika/ReadingProgressMatcher.swift)) walks the target and transcript together with:
- **Edit-distance per-word** (Levenshtein, distance scaled by word length and first-letter agreement) so "ahed"/"ahead" matches.
- **Skip windows**: up to 5 target words can be skipped in total, with a small look-ahead window of 2 — so a user who drops a word or two keeps progressing, but the system won't silently accept "blah blah" as the paragraph.
- **Monotonic progress** in the store (`if progress.completedWordCount >= readingProgress.completedWordCount`) — partial-transcript revisions from Speech can briefly go backwards; we ignore that so the UI doesn't flicker.

The thresholds (5 skipped words, 2-word look-ahead) are the kind of numbers I'd want to tune with real users, but they're isolated to one matcher so tuning is a one-file change.

### 4. Retry on the record button, not buried in a menu
Users will misspeak. The record button doubles as a retry during recording (`toggleRecording` → `retryVoiceRecording`), and once the matcher decides they're done, the same surface becomes playback + checkmark. One control, three states, no dead-end. Same reasoning behind exposing playback before confirm — let people hear it before they commit it to their profile.

### 5. `@MainActor` on stores, async services
Stores are `@MainActor` so view updates are always on the main thread without `DispatchQueue.main.async` sprinkles. Services do their own threading (`AVAudioEngine` tap callback, speech callbacks) and hop back to the actor via `Task { @MainActor in … }`. This keeps the rule simple: state mutation is always on the main actor.

### 6. Single-source-of-truth for fonts/colors
`PikaFonts` and `PikaColors` centralize the design tokens. No view hardcodes a hex or a font name. The few raw RGB values that remain (the lavender CTA color) are flagged as candidates for the next pass once a design token export is available.

### 7. Hero video prewarm
The landing page video stutters on first launch if you let `AVPlayer` lazy-init. `HeroVideoPlayer` prewarms on cold launch (see the prewarm commit). Small touch, but the first impression matters and the brief emphasized caring about the design.

## What I'd revisit with more time

- **Real auth providers.** OTP for phone, ASAuthorization for Sign in with Apple, and a Google SDK wire-up. The seam exists; the sheets don't.
- **`UserRepository` → protocol + async**. Once a backend exists, make the methods `async throws` and split into `LocalUserStore` + `RemoteUserStore` with a coordinator. Right now they're synchronous because Core Data is.
- **Background context for writes.** Photo/audio writes happen on the view context. With real users and larger blobs (audio is currently the whole CAF file in Core Data — see below) this needs a background context + on-disk file references.
- **Audio as a file reference, not a Data blob.** Storing raw CAF in `User.audioData` is fine for the demo but will balloon the store. The right shape is `audioURL: String` pointing at the app's documents directory, with the repo owning lifecycle.
- **Camera UX polish.** Front/back toggle, torch, tap-to-focus, capture flash animation, low-light handling. The capture works; the affordances are minimal.
- **Error UX.** Right now errors surface as inline `errorMessage` strings. A consistent toast / inline banner component would be a small lift and cover all screens.
- **Accessibility pass.** VoiceOver labels exist for the auth socials and a few buttons but not the whole flow. Dynamic Type is honored via `relativeTo:` in `PikaFonts`, but I haven't audited at XXL.
- **Tests around `ReadingProgressMatcher`.** It's pure and the right shape for unit tests; I left it untested to stay in budget but it's the highest-leverage thing to cover.
- **Strip debug logging** from `AudioRecorder` (audio-level prints, transcript prints) — useful during development, noise in prod.
- **State restoration** if the app is killed mid-recording. Today we discard; a real product probably wants to confirm before nuking work.

## Questions / suggestions for the team

### For the designer
- **Voice step error states.** What does "we can't hear you / mic denied / speech recognition unavailable" look like? Today it's an inline red string; the mocks don't cover it.
- **Mid-recording retry affordance.** I made the record button itself the retry control during recording. Is that the intent, or should retry be a secondary button? The mocks show one button, but the interaction model isn't spelled out.
- **Completion threshold.** What's the desired tolerance for "they read it"? I picked 5 skipped words / per-word edit-distance — this should be a product call, not an engineering one.
- **ID card share format.** Today we share a UIImage rendering of the card. Is a deep link / web preview wanted instead (e.g. `pika.app/u/<id>`)? Affects whether sharing needs the backend.
- **Returning user landing.** If a user has completed onboarding and logs back in, what should the landing show — straight to the ID card, a dashboard, or "create another"? Today it always re-enters onboarding at the resume point, which means a fully-onboarded user lands on the complete screen. Likely not the long-term answer.
- **Multiple profiles per identity.** The current flow lets a user dismiss the ID card and "create another profile." Is that real, or an artifact of the demo? If real, the data model needs a one-to-many.

### For the backend engineer
- **Auth contract.** I assumed `(phone | email) → user` with the client minting a `userId` on first sight. Will the server own `userId`? If so, the local `findOrCreateUser` needs a "pending" state until the server responds.
- **Asset upload.** Selfie + audio are persisted locally today. What's the upload shape — multipart on commit, or signed-URL direct-to-S3 per step? Affects whether each step is "save & continue" or "stage & commit at the end."
- **Resume semantics.** Should `nextStep` be computed server-side (so a different device picks up the same place) or stay client-side? Today it's purely local — fine for a single-device user, breaks for multi-device.
- **Speech recognition.** On-device `SFSpeechRecognizer` is what's wired today. If you want consistent matching across devices/locales, this probably needs to move server-side with the audio upload — happy to swap once you have an endpoint.
- **ID card source of truth.** The card currently renders client-side from the user's row. If the "AI self" generation lives on the server, I need a `GET /users/:id/card` shape (image URL? structured fields?) — let me know and I'll thread it through `CompleteStepStore`.

## Running

Open `Pika/Pika.xcodeproj` in Xcode 15+ and run on iOS 17+.

### Test on a real device

**This app must be exercised on a physical device, not the simulator.** Two of the three onboarding steps depend on hardware the simulator can't provide:

- **Photo step** uses `AVCaptureSession` against the front camera. The simulator has no camera — the preview will be black and capture will fail silently.
- **Voice step** uses the microphone + `SFSpeechRecognizer` against the live audio buffer. The simulator can route Mac audio in some configurations, but speech recognition is unreliable and the reading-progress matcher won't fire convincingly. You won't be able to evaluate the matcher, the retry flow, or the auto-advance behavior without a real mic.

The auth / landing / complete-card screens render fine in the simulator if you only want to inspect layout, but the full flow needs hardware.

### How to use the session

1. Plug in an iOS 17+ device, trust the Mac, and select it as the run destination in Xcode.
2. First launch will prompt for **Microphone**, **Speech Recognition**, and **Camera** permission inline at the step that needs each one. Grant all three — denying any will surface an inline error on the affected step.
3. Walk the flow: enter a phone number → take a selfie → read the on-screen paragraph aloud → tap the checkmark → share or save the ID card → dismiss to return to landing.
4. To verify resume: kill the app mid-flow and relaunch with the same phone number. You should land back on the step you left.
5. To verify the matcher tolerance: deliberately mumble or skip a word or two during the voice step — progress should still advance. Misread badly enough and you'll stall; tap the record button again to retry.

If you change the bundle id, make sure Info.plist still carries `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, and `NSCameraUsageDescription` — without them, the permission prompts won't appear and the steps will silently fail.
