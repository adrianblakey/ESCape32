# Setup

One-time setup to get the build-and-release pipeline running. The Docker
image and the workflow files (`.github/workflows/build-image.yml` and
`release.yml`) are already in this repo — this is what's left to make the
release side actually work.

## 1. Create the two release repos

```bash
gh repo create adrianblakey/escape32-firmware-internal --private --description "Internal/test ESCape32 firmware builds"
gh repo create adrianblakey/escape32-firmware --public --description "ESCape32 firmware releases"
```

Using the GitHub UI instead is equivalent — the workflow only needs
`owner/repo` strings to publish releases into. If you pick different names,
update `PRIVATE_REPO`/`PUBLIC_REPO` in `.github/workflows/release.yml` to match.

## 2. Create a PAT for cross-repo releases

The default `GITHUB_TOKEN` a workflow gets can only act on the repo it's
running in, so creating releases in the two *other* repos needs a Personal
Access Token.

- GitHub -> Settings -> Developer settings -> Personal access tokens -> Fine-grained tokens -> Generate new token
- Resource owner: yourself
- Repository access: **Only select repositories** -> pick exactly `escape32-firmware-internal` and `escape32-firmware` (not this firmware source repo)
- Permissions: **Contents: Read and write** (this alone covers creating releases)
- Generate, copy the token

Add it as a secret in **this repo** (the firmware source repo):
- Settings -> Secrets and variables -> Actions -> New repository secret
- Name: `RELEASE_PAT`
- Value: the token

## 3. Set up the public-release approval gate

- In this repo: Settings -> Environments -> New environment -> name it `public-release`
- Under "Deployment protection rules", add yourself (and anyone else you want able to approve) as required reviewers

With this in place, every push to `master` builds and auto-publishes to the
private repo immediately, but the public-repo job pauses in the Actions tab
waiting for an approval click before anything goes out publicly.

## 4. First run

1. Push `docker/Dockerfile` to `master` (already there after this setup) — this triggers `build-image.yml` and publishes the image to GHCR. Check this repo's Packages tab to confirm it landed. If it doesn't trigger automatically the first time, run it manually: Actions -> Build & Push Builder Image -> Run workflow.
2. Push a firmware change to `master` — this triggers `release.yml`: builds via the now-published image, creates the private release immediately, and leaves the public release waiting in Actions for your approval.

## Notes on this pipeline vs. a typical fork

This repo doesn't currently have any targets that should stay private-only —
every `.bin`/`.hex` the build produces goes into both the private and public
release, the only difference being the public one needs your manual
approval. If you later add a private/internal-only target, adjust the
"Collect artifacts" step in `release.yml` to split them (e.g. copy
private-only target names into a second directory and give
`publish-private`/`publish-public` their own artifact each, the way you'd
expect).

## Upstream change notifications (no setup needed)

On `neoxic/ESCape32`: Watch (top right) -> Custom -> tick "Releases" only.
You'll get notified whenever a new tagged release lands upstream, without
watching every commit.
