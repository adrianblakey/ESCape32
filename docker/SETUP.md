# Setup

One-time setup to get the build-and-release pipeline running. The Docker
image and the workflow files (`.github/workflows/build-image.yml` and
`release.yml`) are already in this repo — this is what's left to make the
release side actually work.

## 1. Create the release repo

```bash
gh repo create adrianblakey/escape32-firmware --public --description "ESCape32 firmware releases"
```

Using the GitHub UI instead is equivalent — the workflow only needs an
`owner/repo` string to publish releases into. If you pick a different name,
update `PUBLIC_REPO` in `.github/workflows/release.yml` to match.

## 2. Create a PAT for cross-repo releases

The default `GITHUB_TOKEN` a workflow gets can only act on the repo it's
running in, so creating a release in the *other* repo needs a Personal
Access Token.

- GitHub -> Settings -> Developer settings -> Personal access tokens -> Fine-grained tokens -> Generate new token
- Resource owner: yourself
- Repository access: **Only select repositories** -> pick exactly `escape32-firmware` (not this firmware source repo)
- Permissions: **Contents: Read and write** (this alone covers creating releases)
- Generate, copy the token

Add it as a **repository secret** in **this repo** (the firmware source
repo) — not an environment secret, since the workflow's `publish-public`
job needs it available before the environment approval step:
- Settings -> Secrets and variables -> Actions -> Repository secrets tab -> New repository secret
- Name: `RELEASE_PAT`
- Value: the token

## 3. Set up the public-release approval gate

- In this repo: Settings -> Environments -> New environment -> name it `public-release`
- Under "Deployment protection rules", add yourself (and anyone else you want able to approve) as required reviewers

With this in place, every push to `master` builds firmware, and the
publish job pauses in the Actions tab waiting for an approval click before
anything goes out to the public release repo.

## 4. First run

1. Push `docker/Dockerfile` to `master` (already there after this setup) — this triggers `build-image.yml` and publishes the image to GHCR. Check this repo's Packages tab to confirm it landed. If it doesn't trigger automatically the first time, run it manually: Actions -> Build & Push Builder Image -> Run workflow.
2. Push a firmware change to `master` — this triggers `release.yml`: builds via the now-published image, then leaves the release waiting in Actions for your approval.

## Upstream change notifications (no setup needed)

On `neoxic/ESCape32`: Watch (top right) -> Custom -> tick "Releases" only.
You'll get notified whenever a new tagged release lands upstream, without
watching every commit.
