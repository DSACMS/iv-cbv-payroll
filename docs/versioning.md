# Versioning Emmy App

Emmy App follows [semantic versioning](https://semver.org) — `MAJOR.MINOR.PATCH` —
with **one deliberate deviation: user-facing interface changes are promoted to
MAJOR.**

## Why we deviate

States train staff and applicants using paper-based and other static materials —
printed guides, screenshots, pre-recorded video. Those materials can't be
hot-patched. So a change we'd normally call cosmetic (new button text, a new
confirmation screen) can silently invalidate a state's training library.

Standard semver only protects API consumers. Emmy's real interface contract also
includes the screens people were trained on.

## The rubric

**MAJOR** — requires notification to states, who should expect to update training
materials or integrations.

- Breaking changes: client interfaces, apps, or API requests must be updated.
- Significant changes to the application process, *including visual-only changes
  that alter the wireframe*.

**MINOR** — worth reading about; no retraining required.

- New capability at the data layer (e.g. additional parameters returned on API
  requests).
- Changes visible to applicants that don't affect the wireframe.
- Any change to an admin interface, including visual-only ones (yes, the social
  worker interface is deprecated — still counts).

**PATCH**

- Bugfixes.
- Silent updates invisible to all users.

### Examples

*Minor* — color and typeface updates. No changes to text, positioning, or
workflow. Existing screenshots still match closely enough to train from.

*Major* — visual design and button placement are unchanged, but:

- Button text changed, so a printed script no longer matches.
- Added applicant feedback may change the application flow.

### The tiebreaker

**Could a state's existing training material now mislead someone?** If yes, it's
MAJOR — regardless of how small the code change was.

## While we are pre-1.0

Emmy App is at `0.x`. Per [semver §4](https://semver.org/#spec-item-4), major
version zero means the public interface is not yet stable, which is accurate: the
app is piloted with a handful of states and is not yet in general production use.

During the pilot the rubric shifts one position left, so **the middle digit is
the notification trigger**:

| Rubric tier | Bump | Example |
| --- | --- | --- |
| MAJOR | middle digit | `0.1.0` → `0.2.0` |
| MINOR or PATCH | last digit | `0.1.0` → `0.1.1` |

Neither MINOR nor PATCH requires notification, so collapsing them into the last
digit costs states nothing — the changelog entry still records which tier a
change belonged to. The contract we teach states is one sentence: *if the middle
number moved, check your training materials.*

We cut `1.0.0` when the first state goes to production, and expand to the full
three-slot rubric then.

## Where the version lives

- [`app/version.txt`](../app/version.txt) is the single source of truth. Bump it
  in the release PR.
- [`code.json`](../code.json) mirrors it for federal source-code inventory.
- `EmmyVersion.current` reads `version.txt` at runtime.
- `GET /health` reports it as `version`, so states can check which version an
  environment is running. (The `ref` field in that response is the deployed
  image tag.)

## Scope of this version line

`0.1.0` describes **Emmy App** — the Rails application in this repository. Two
adjacent interfaces are versioned separately and are not covered by this number:

- **Emmy API**, which lives in [CMSgov/emmy-api](https://github.com/CMSgov/emmy-api).
- The HTTP endpoints under `/api` in this repository, which are partly versioned
  by path today: `config/routes.rb` scopes `/invitations` under `v1`, while the
  `pinwheel`, `argyle`, and `events` endpoints sit outside any version scope.
  Consolidating those under a versioned scope is open work.

## Release checklist

See [release-process.md](./release-process.md).
