---
title: docker-credential-osxkeychain
description: Docker credential helper backed by the macOS login Keychain — keeps registry credentials out of a plaintext config.json. No host setup required.
keywords: docker,credential-helper,osxkeychain,keychain,macos,darwin,registry,credentials,credsstore,docker-login,security,apple
---

# docker-credential-osxkeychain

A credential helper keeps your registry passwords **out of
`~/.docker/config.json`**, where they otherwise sit base64-encoded — obfuscated,
not encrypted, readable by anything that can read the file. `docker login` and
everything else that speaks Docker's credential-store protocol hands the
credential to a helper instead, which stores it in a real keystore.

This one is the **macOS backend**: credentials go into your **login Keychain**
through Keychain Services, the same store Safari and the system use. It is the
right choice on any Mac — encrypted at rest, unlocked with your login password,
and inspectable in Keychain Access.app.

OCX's own registry auth reads the Docker credential store too, so this is the
helper that secures `ocx`'s credentials as well as Docker's.

## No host setup required

Unlike the Linux backends in this family, this package needs **nothing installed
on your machine**. The Keychain is an operating-system service, and the binary
links only against frameworks macOS already ships — `Security.framework`,
`CoreFoundation`, `libresolv` and `libSystem`. Install it and it works.

(For contrast: **docker-credential-pass** needs the `pass` CLI and a GnuPG key,
and **docker-credential-secretservice** needs `libsecret` plus a running keyring
daemon. Neither applies here.)

Both Apple Silicon and Intel Macs are published as native binaries — this is not
one universal build, but a separate `darwin/arm64` and `darwin/amd64` artifact,
so you get a native executable either way and no Rosetta translation.

## What's included

- **docker-credential-osxkeychain** — the single binary. Docker resolves it from
  `PATH` by this exact name; do not rename it.

## Usage

Point Docker at the helper by setting `credsStore` in `~/.docker/config.json` —
the value is the helper's name **minus** the `docker-credential-` prefix:

```json
{
  "credsStore": "osxkeychain"
}
```

From then on `docker login` writes to the login Keychain instead of the config
file, and `docker pull` reads back out of it. Existing plaintext `auths` entries
are not migrated — run `docker logout <registry>` and log in again to move them.

The first time the helper reads a credential, macOS asks whether to allow it
access to that Keychain item. Choose **Always Allow** to avoid a prompt on every
`docker pull`.

To check the whole chain end to end:

```sh
echo '{"ServerURL":"https://example.org","Username":"alice","Secret":"s3cr3t"}' \
  | docker-credential-osxkeychain store
docker-credential-osxkeychain list          # → {"https://example.org":"alice"}
```

Stored items show up in **Keychain Access.app** under the server URL, so you can
audit or delete them without the CLI.

Sibling backends ship from the same upstream release — **docker-credential-pass**
for headless machines and CI (it has a macOS build too, if you prefer a GnuPG
store to the Keychain), **docker-credential-secretservice** for Linux desktops,
and **docker-credential-wincred** for Windows Credential Manager.

## Links

MIT licensed.

- [docker-credential-helpers on GitHub](https://github.com/docker/docker-credential-helpers)
- [Docker credential store documentation](https://docs.docker.com/reference/cli/docker/login/#credential-stores)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
