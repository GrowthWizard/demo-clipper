# Clipper Requesty

A fork of [Desert Ant Labs' Clipper](https://github.com/Desert-Ant-Labs/demo-clipper)
with optional **GLM 5.3 Flash clip selection through Requesty**. Voz still transcribes
locally. Requesty mode finds and editorially reviews candidates and drafts their
titles and descriptions with GLM. The original Clips selector and Title model
remain available in local mode. Sentence editing, preview, subtitles and
AVFoundation export stay local.

Choose **Clip Selection** in the toolbar. Requesty mode offers clip count,
maximum duration (10–60 seconds), focus, a LinkedIn/general destination, audience,
content goal, additional editorial instructions and a
GLM 5.3 Flash model choice. The same window has a masked **Requesty API key** field
and a router field. **Select Again** reuses the existing transcript and
replaces clips only after a successful selection. A failed request keeps the
previous clips. Selection can be cancelled.

GLM 5.3 Flash runs two bounded requests: candidate discovery over the transcript,
then a separate editorial review of the proposed ranges. The reviewer can tighten
an excerpt or add up to two adjacent sentences for context. Each candidate is
checked for a clear opening, complete thought, one main topic, specific value and
faithful metadata. Failed checks, invented evidence, overlapping accepted ranges
and extra accepted clips are excluded locally. Nothing falls back to unreviewed
candidates. If none pass, the existing selection is preserved.

The LinkedIn profile prioritizes concrete problems, reasoned decisions and useful
professional insights, and excludes candidates requiring unseen visual context.
The general profile can retain a demonstration and labels that context requirement.
Count is an upper limit, not a quota. The inspector shows the takeaway, selection
reason, context needed, exact source evidence and how many candidates were excluded.
These are model judgments, not measured performance or an assurance of publication
quality. Editing a clip marks its assessment as belonging to the original selection.
Requesty titles use the reviewed excerpt; local Title cannot overwrite them.

GLM returns ranked, contiguous sentence-ID ranges, never generated timecodes.
The app rejects missing/reversed IDs, overlaps, malformed responses and clips
whose actual SDK cut duration, including padding, exceeds the requested maximum
or 60 seconds. Manual additions and export keep Requesty clips within 60 seconds.
The inspector shows their rank without inventing a local Clips confidence score.
The selection is editorial advice: check the transcript and preview before posting.

Only the transcript and editorial preferences leave the Mac in Requesty mode.
The client uses the Chat Completions API with a strict JSON schema, `store: false`,
an ephemeral session, no redirects and sanitized errors. Requesty/provider
logging and retention depend on the account settings; `store: false` alone does
not disable gateway logging. The EU router controls Requesty processing;
provider inference residency depends on the selected model.
The request uses `reasoning_effort: "none"` to leave the bounded output budget
available for the candidates, review and evidence. Incomplete output is rejected rather than cut.
See [Requesty data privacy](https://docs.requesty.ai/features/data-privacy) and
[EU routing](https://docs.requesty.ai/features/eu-routing).

## Build this fork

Apple Silicon, macOS 26+, Xcode with its Metal Toolchain, and xcodegen are required.
Install xcodegen with `brew install xcodegen`; if Xcode reports a missing Metal
Toolchain, use `xcodebuild -downloadComponent MetalToolchain`.

```bash
git clone https://github.com/GrowthWizard/demo-clipper.git
cd demo-clipper
./script/build_and_run.sh run
./script/build_and_run.sh test
```

The app is named **Clipper Requesty** with its own bundle ID, so it can coexist
with the original app. Its update checker follows this fork's releases. The
Desert Ant core is pinned to 3.3.1, matching the upstream 1.0.5 release used here.
The build scripts avoid an observed Xcode 26.6 command-line probe stall by
omitting verbose diagnostics from the Clang macro probe. Compilation flags and
macro output are unchanged.

### Requesty in the app

Open **Clip Selection**, choose **GLM 5.3 Flash via Requesty**, and enter your Requesty
API key. Choose a model available to your key (for example `glm-5.3-flash@eu`). The
default router is `https://router.eu.requesty.ai/v1`. The default model ID
`glm-5.3-flash@eu` routes through EU providers. This version accepts only
GLM 5.3 Flash, including its named provider deployments; the key must permit
the exact chosen ID. Catalog visibility alone does not prove model access.

Enable **Remember access in macOS Keychain** to save the key, router and model
in this app's encrypted login Keychain item. This item does not sync to iCloud.
Without that option, the values stay in memory until you quit. Disabling it
and clicking **Done** removes this app's saved item. Keys are never saved in
preferences, project files or logs.

The app works when opened through Finder or the Codex Run action. No 1Password
mount is required. A failed Keychain save keeps the settings window open with
an error; you can choose session-only access instead.

### Optional process configuration and CLI

Use the `1password-project-env` skill and the official local 1Password MCP.
Create or reuse a dedicated Clipper/local environment, save these variables,
and copy the metadata template `.1password/project.example.json` to
`.1password/project.json` with your account/environment IDs. The real binding
is gitignored and contains metadata only.

| Variable | Required | Purpose |
|---|---|---|
| `REQUESTY_API_KEY` | Yes | Concealed Requesty key with access to the chosen model |
| `REQUESTY_BASE_URL` | Yes | `https://router.eu.requesty.ai/v1` or another supported Requesty router |
| `REQUESTY_MODEL` | Yes | GLM 5.3 Flash model ID, e.g. `glm-5.3-flash@eu`, with Structured Outputs support |

For a managed environment launch, mount the environment as the skill's FIFO
outside the checkout. Do not create plain-text `.env` copies. Then run:

```bash
./script/build_and_run.sh run-1password
```

This optional launcher injects the values with the skill runner and passes them
in memory to LaunchServices. They seed the app's API fields for that session;
click **Done** with Keychain storage enabled to remember them. Restart an
environment-launched app after changing its process values.

For the CLI, build with `./script/build_and_run.sh cli` and launch through the
same skill runner. Add `--requesty --count 5 --max-duration 60 --focus context`
(or `hook` / `balanced`), optionally `--destination linkedin|general`, `--audience`,
`--content-goal`, `--model glm-5.3-flash@eu` and `--instructions`. JSON reports
include the editorial assessment and source evidence for each Requesty clip.
The CLI defaults to the original local selector; no automatic remote/local fallback
runs after a Requesty error.

The CLI reads `REQUESTY_API_KEY`, `REQUESTY_BASE_URL` and `REQUESTY_MODEL` from
its process environment. The GUI's Keychain item is not read by the CLI.

## Original Clipper documentation


The original app generates short clips from a video podcast, meeting recording, or longer
recording, fully on device. A local macOS app and a command-line tool over the
same core.

![The Clipper app: the clip list, the preview, the transcript and the timeline](docs/clipper.png)

## Download the original app

Homebrew is the one to use, because `brew upgrade` moves you to the next
release:

```bash
brew tap desert-ant-labs/tap
brew install --cask clipper
```

Homebrew 6 asks you to approve a tap it has not seen before. Answering that
prompt covers Clipper, and `brew trust desert-ant-labs/tap` covers anything
Desert Ant publishes later.

Or download the [disk image](https://github.com/Desert-Ant-Labs/demo-clipper/releases/latest)
and drag Clipper to Applications. Clipper works on macOS 26 or later on Apple
Silicon.

The three models come off Hugging Face on first run and are cached for every
run after: Voz is 466MB, Title 280MB, Clips 275MB. Nothing is uploaded and
nothing needs an account.

Clipper reads the latest release tag at launch and says nothing unless there is
a newer one. Check for Updates in the Clipper menu runs the same check and
always answers. Nothing installs itself.

```
video ──► audio ──► Voz ──► sentences ──► Clips ──► Title ──► AVFoundation ──► mp4
```

[Voz](https://desertant.com/models/voz/) transcribes the audio with a time on
every word. [Clips](https://desertant.com/models/clips/) scores the sentences
and returns the best spans, ranked. [Title](https://desertant.com/models/title/)
writes a title and a description for each one. AVFoundation cuts the source to
the picked ranges, so you export finished mp4s and post them.

## Run it

The tasks run through [mise](https://mise.jdx.dev) (`brew install mise`), which
pins xcodegen.

```bash
git clone https://github.com/Desert-Ant-Labs/demo-clipper.git
cd demo-clipper
mise trust && mise install
mise run run       # build Release and open the app
```

The three models come off the Hub on first use and are cached, so nothing has
to be installed first. `mise run models` fetches them ahead of that run, which
is worth doing before a demo: Title alone is 280MB.

Drop a video on the window, open one with the toolbar button, or pass one to
the app: `open -a Clipper my-talk.mp4`. Pick a clip to preview the cut, then
export that clip or all of them.

A recording with no picture works the same way. Clipper picks clips out of what
is said, so an m4a or a wav is as good a source as a video: the preview is a
transport rather than a picture, and the clips come out as m4a.

The other tasks are `build`, `cli`, `test`, `xcode` (generate and open the
project), `package` (build and wrap the app in a disk image), and `clean`.

## The command line tool

```bash
mise run cli
build/Build/Products/Release/clipper my-talk.mp4 --out ./clips
```

| flag | what it does |
|---|---|
| `--out <dir>` | where to write the mp4s (default: working directory) |
| `--count <n>` | keep only this many of the ranked clips (default: all of them) |
| `--from-transcript <file>` | clip a JSON transcript instead of a video |
| `--clips-model <dir>` | read the Clips model from here |
| `--title-model <dir>` | read the card model from here |
| `--voz-model <dir>` | read the Voz model from here |
| `--no-titles` | pick the clips and skip writing them |
| `--dry-run` | find and print clips without exporting |
| `--transcript` | print the timed transcript and stop |
| `--json` | print the result as JSON |

Progress goes to stderr and results to stdout, so `--json` pipes cleanly:

```bash
clipper my-talk.mp4 --dry-run --json | jq -r '.clips[].title'
```

`--from-transcript` runs the models on a transcript alone: no audio, no export.
The file holds a list of sentences, an object with a `sentences` key, or a list
of either, so you can check a run against a reference.

## How it is put together

```
App/Sources/           the SwiftUI app
App/Sources/Clipping/  Speech, Reader, ClipFinder, Pick, Cutting, shared with the CLI
CLI/                   the clipper tool, built by the ClipperCLI target
Tests/                 the suites, over App/Sources/Clipping
project.yml            xcodegen. Clipper.xcodeproj is generated and gitignored
```

The app, the CLI and the tests compile one shared set of sources.
`App/Sources/Clipping` holds everything that is neither SwiftUI nor argument
parsing.

The core makes the clip decisions. `Sentence` splits the words, `Clips` chooses
the moments, `Clip.ranges` gives the spans, and `Titles` writes the cards. The
SDK's work starts at timed words and stops at clips and time spans, so reading
the audio and cutting the file are this app's. Replace `Speech.swift` and
`Cutting.swift` if you bring your own recognizer or your own editor.

`mise run models` installs all three under `~/Library/Application
Support/Clipper/Models`, and `CLIPPER_CLIPS_MODEL`, `CLIPPER_TITLE_MODEL` and
`CLIPPER_VOZ_MODEL` point somewhere else. A model with no directory of its own
resolves through the SDK's managed cache in `~/Library/Caches/desert-ant-models`,
which downloads the revision the SDK is pinned to.

## Requirements

macOS 26 or later on Apple Silicon, and Xcode 27. MLX has no x86_64 backend and
Voz's Core ML buffers are `Float16`, so the `mise` tasks pass `ARCHS=arm64`.
Building from Xcode's UI needs the same.

Both packages resolve from their released tags:
[`desert-ant-core`](https://github.com/Desert-Ant-Labs/desert-ant-core) for the
models, [`desert-ant-swift`](https://github.com/Desert-Ant-Labs/desert-ant-swift)
for the brand kit. `Packages/MLXTrait` is a local manifest that enables the
core's `MLX` trait, which an Xcode project cannot declare on its own.

To sign with your own certificate, run `mise set --file mise.local.toml
CLIPPER_TEAM_ID=XXXXXXXXXX`. Left alone, a build is signed to this machine.

`mise run package` wraps a Release build in a disk image. With a Developer ID
certificate in your keychain it signs with it, and with
`NOTARY_PROFILE=<name>` it notarizes and staples too, so the image opens on a
machine that has never seen it. Without either it still builds, and says which
of the two it did not do.

## License

Clipper's source is MIT. See [`LICENSE`](LICENSE).

The models are licensed separately, under the [Desert Ant Labs Source-Available
License 1.0](https://license.desertant.com/1.0). You can ship them free below
100,000 monthly active devices per platform for each model, you credit Desert
Ant Labs, and you may not train a competing on-device model from the models,
their outputs, or their logs. Attribution guidance at
<https://license.desertant.com/attribution>, commercial licensing at
<licensing@desertant.com>.

The `desert-ant-swift` brand kit is MIT; the Desert Ant name and mark stay
trademarks. Everything that ships is listed in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
