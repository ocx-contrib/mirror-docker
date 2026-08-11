# mirror-docker

OCX mirrors for [docker-credential-helpers](https://github.com/docker/docker-credential-helpers).
Publishes upstream GitHub releases to `ghcr.io/ocx-contrib/docker/*` with
cascade tags after a smoke test per `(version, platform)`, then announces the
result into the OCX index under `ocx.sh/docker/*`.

Opened for [ocx-sh/ocx#309](https://github.com/ocx-sh/ocx/issues/309).

## What these are

Docker credential helpers keep registry passwords **out of a plaintext
`~/.docker/config.json`**, where they otherwise sit base64-encoded — obfuscated,
not encrypted. `docker login` and everything else that speaks Docker's
credential-store protocol resolves a helper from `PATH` by the name
`docker-credential-<backend>` and hands the credential to it instead.

That includes OCX itself: registry auth falls back to the Docker credential
store, and `ocx-mirror`'s getting-started guide tells publishers to authenticate
with `docker login`. So these are the binaries that secure OCX's own auth path.

## Four packages, one upstream release

Upstream ships **one standalone binary per keystore backend** from a single tag.
Each backend is its own OCX package, because the backend is a **user choice, not
a platform axis** — `pass` and `secretservice` both target Linux, and a user
picks between them by whether their machine has a desktop session or a GnuPG
store. One merged package would have to choose for them.

| Package | Backend | Platforms | Host requirement |
|---|---|---|---|
| [`docker/docker-credential-pass`](https://index.ocx.sh/docker/docker-credential-pass) | `pass` + GnuPG | linux/{amd64,arm64}, darwin/{amd64,arm64} | `pass` CLI and an initialised store |
| [`docker/docker-credential-secretservice`](https://index.ocx.sh/docker/docker-credential-secretservice) | freedesktop Secret Service | linux/{amd64,arm64} (glibc) | `libsecret` + a keyring on D-Bus |
| [`docker/docker-credential-osxkeychain`](https://index.ocx.sh/docker/docker-credential-osxkeychain) | macOS login Keychain | darwin/{amd64,arm64} | none — OS frameworks |
| [`docker/docker-credential-wincred`](https://index.ocx.sh/docker/docker-credential-wincred) | Windows Credential Manager | windows/{amd64,arm64} | none — platform API |

Each package's `CATALOG.md` carries its own host requirements with copy-paste
install commands; the index renders them on the package page.

**`os.features` carries a libc family and nothing more**, so a runtime
dependency past libc — `libsecret`, `gpg` — has no declarable home in the spec.
The CATALOG is the only place a consumer learns about it, which is why those
sections are not optional prose.

## Two libc claims in one repo

`docker-credential-pass` is **fully static** (no `PT_INTERP`, no `DT_NEEDED`, no
versioned GLIBC symbols on either arch) so it takes **bare** `linux/*` keys — a
positive claim that it needs no particular libc, which the alpine container leg
is what proves.

`docker-credential-secretservice` is **dynamically linked against glibc** and
pulls `libsecret-1`/`libgio-2.0`/`libgobject-2.0`/`libglib-2.0`, so it takes
`linux/*+libc.glibc` keys, gets no alpine leg, and each of its container legs
installs `libsecret` via `containers[].setup`. Its glibc floor is **2.34** at
v0.9.8, measured per arch.

Both families live as separate keys in the root `mirror-base.yml`, so no spec
restates `platforms:` and the shallow-merge trap cannot bite. Each spec's own
evidence block records the commands and their output.

## Editing

One directory per package, each holding its own `mirror.yml`, `metadata.json`,
`CATALOG.md` and `tests/`. `mirror-base.yml` at the root carries what they share
(`platforms:`, `concurrency:`, `notify:`, `verify:`, `skip_prereleases`,
`cascade`, `build_timestamp`); each spec pulls it in with
`extends: ../mirror-base.yml`. **The merge is shallow** — a spec that restates
`platforms:` must restate the whole block, including its container legs.

| File | Edit | Regenerate after |
|------|------|------------------|
| `<pkg>/mirror.yml`, `mirror-base.yml` | hand | `ocx-mirror package pipeline generate ci` |
| `<pkg>/tests/smoke.star` | hand | — |
| `<pkg>/metadata.json`, `<pkg>/CATALOG.md`, `logo.*` | hand | — |
| `.github/workflows/*.yml` | generated | re-run when any spec changes |

`--spec` **appends** rather than replaces, so name every spec in the repo or the
unnamed ones silently stop being rendered while CI stays green:

```sh
ocx-mirror package pipeline generate ci \
  --spec docker-credential-pass/mirror.yml \
  --spec docker-credential-secretservice/mirror.yml
```

CI fails on drift via `ocx-mirror package pipeline generate ci --check`.

`versions.poll_interval` on each spec is a **hash-staggered** cron from
`poll_stagger.py`, never a hand-picked minute — fleet-synchronized crons
burst-pushed to GHCR together and tripped its secondary rate limit on
2026-08-04.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from `ocx-contrib/index` |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

The GHCR push uses the run's own `GITHUB_TOKEN` (`permissions: packages: write`),
so it needs no registry secret. (Both inherited from the `ocx-contrib` org with
visibility ALL.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are MIT and out of scope;
see [`NOTICE.md`](NOTICE.md).
