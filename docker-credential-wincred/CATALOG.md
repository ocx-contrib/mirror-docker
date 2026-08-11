---
title: docker-credential-wincred
description: Docker credential helper backed by Windows Credential Manager — keeps registry credentials out of a plaintext config.json. No host setup required.
keywords: docker,credential-helper,wincred,credential-manager,windows,registry,credentials,credsstore,docker-login,dpapi
---

# docker-credential-wincred

A credential helper keeps your registry passwords **out of
`%USERPROFILE%\.docker\config.json`**, where they otherwise sit base64-encoded —
obfuscated, not encrypted, readable by anything that can read the file.
`docker login` and everything else that speaks Docker's credential-store
protocol hands the credential to a helper instead, which stores it in a real
keystore.

This one is the **Windows backend**: credentials go into **Windows Credential
Manager**, the same store the OS uses for network and application credentials.
They are encrypted against your user account and manageable from Control Panel.

OCX's own registry auth reads the Docker credential store too, so this is the
helper that secures `ocx`'s credentials as well as Docker's.

## No host setup required

Unlike the Linux backends in this family, this package needs **nothing installed
on your machine**. Credential Manager is an operating-system service reached
through the Windows API. Install it and it works.

(For contrast: **docker-credential-pass** needs the `pass` CLI and a GnuPG key,
and **docker-credential-secretservice** needs `libsecret` plus a running keyring
daemon. Neither applies here.)

Both `windows/amd64` and `windows/arm64` are published as native binaries — an
ARM64 device gets a native executable, not an emulated x64 one.

## What's included

- **docker-credential-wincred** — the single binary, shipped as
  `docker-credential-wincred.exe`. Docker resolves it from `PATH` by the bare
  name; do not rename it.

## Usage

Point Docker at the helper by setting `credsStore` in
`%USERPROFILE%\.docker\config.json` — the value is the helper's name **minus**
the `docker-credential-` prefix and **without** the `.exe`:

```json
{
  "credsStore": "wincred"
}
```

From then on `docker login` writes to Credential Manager instead of the config
file, and `docker pull` reads back out of it. Existing plaintext `auths` entries
are not migrated — run `docker logout <registry>` and log in again to move them.

To check the whole chain end to end (PowerShell):

```powershell
'{"ServerURL":"https://example.org","Username":"alice","Secret":"s3cr3t"}' |
  docker-credential-wincred store
docker-credential-wincred list          # → {"https://example.org":"alice"}
```

Stored entries appear under **Control Panel → Credential Manager → Windows
Credentials**, named for the server URL, so you can audit or remove them without
the CLI.

Sibling backends ship from the same upstream release — **docker-credential-pass**
for headless Linux and CI, **docker-credential-secretservice** for Linux
desktops, and **docker-credential-osxkeychain** for the macOS login Keychain.

## Links

MIT licensed.

- [docker-credential-helpers on GitHub](https://github.com/docker/docker-credential-helpers)
- [Docker credential store documentation](https://docs.docker.com/reference/cli/docker/login/#credential-stores)
