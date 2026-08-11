---
title: docker-credential-secretservice
description: Docker credential helper backed by the freedesktop Secret Service — keeps registry credentials out of a plaintext config.json, in your Linux desktop keyring. Needs libsecret and a running keyring daemon.
keywords: docker,credential-helper,secretservice,libsecret,gnome-keyring,kwallet,keepassxc,dbus,registry,credentials,credsstore,docker-login,linux,desktop
---

# docker-credential-secretservice

A credential helper keeps your registry passwords **out of
`~/.docker/config.json`**, where they otherwise sit base64-encoded — obfuscated,
not encrypted, readable by anything that can read the file. `docker login` and
everything else that speaks Docker's credential-store protocol hands the
credential to a helper instead, which stores it in a real keystore.

This one is the **Secret Service backend**: credentials go into your Linux
desktop's keyring over the
[freedesktop.org Secret Service D-Bus API](https://specifications.freedesktop.org/secret-service-spec/) —
GNOME Keyring, KWallet, or KeePassXC, whichever is registered on your session
bus. It is the backend that fits a **graphical desktop session**, where the
keyring is already unlocked at login.

On a headless machine — a server, a container, anything reached over SSH —
there is no session bus and no keyring daemon. Use the sibling
**docker-credential-pass** package there instead; it is designed for exactly
that case.

OCX's own registry auth reads the Docker credential store too, so this is the
helper that secures `ocx`'s credentials as well as Docker's.

## ⚠️ Requires libsecret and a running keyring on the host

This package ships **one dynamically linked binary and nothing else**. It links
against `libsecret-1`, `libgio-2.0`, `libgobject-2.0`, `libglib-2.0` and glibc,
and it talks to a keyring daemon over D-Bus at runtime. None of that can be
bundled inside an OCX package — install it with your system package manager:

| System | Install |
|---|---|
| Debian / Ubuntu | `sudo apt-get update && sudo apt-get install -y libsecret-1-0 gnome-keyring` |
| Fedora / RHEL / CentOS | `sudo dnf install -y libsecret gnome-keyring` |
| Arch | `sudo pacman -S --needed libsecret gnome-keyring` |

`libsecret` pulls glib/gio/gobject as its own dependencies, so one command
covers the whole library closure. Substitute `kwalletmanager` or `keepassxc` for
`gnome-keyring` if that is your keyring — any provider registered on
`org.freedesktop.secrets` works.

Without `libsecret` the binary does not start at all, and says so plainly:

```
docker-credential-secretservice: error while loading shared libraries:
libsecret-1.so.0: cannot open shared object file: No such file or directory
```

Two further requirements the package cannot check for you:

- **glibc 2.34 or newer.** Ubuntu 22.04+, Debian 12+, Fedora 35+ and RHEL 9+ all
  qualify. Ubuntu 20.04 (glibc 2.31), Debian 11 (2.31) and RHEL 8 (2.28) do not.
  There is no musl build — Alpine is not supported.
- **An active D-Bus session with an unlocked keyring.** Over SSH or in a
  container, `list` and `get` fail with `Cannot spawn a message bus without a
  machine-id` even though the binary itself is fine. That is the environment
  talking, not the package.

To check the whole chain end to end once it is set up:

```sh
echo '{"ServerURL":"https://example.org","Username":"alice","Secret":"s3cr3t"}' \
  | docker-credential-secretservice store
docker-credential-secretservice list          # → {"https://example.org":"alice"}
```

## What's included

- **docker-credential-secretservice** — the single binary. Docker resolves it
  from `PATH` by this exact name; do not rename it.

## Usage

Point Docker at the helper by setting `credsStore` in `~/.docker/config.json` —
the value is the helper's name **minus** the `docker-credential-` prefix:

```json
{
  "credsStore": "secretservice"
}
```

From then on `docker login` writes to the keyring instead of the config file,
and `docker pull` reads back out of it. Existing plaintext `auths` entries are
not migrated — run `docker logout <registry>` and log in again to move them.

Sibling backends ship from the same upstream release — **docker-credential-pass**
for headless Linux and CI, **docker-credential-osxkeychain** for the macOS login
Keychain, and **docker-credential-wincred** for Windows Credential Manager. Each
is one `ocx add` away.

## Links

MIT licensed.

- [docker-credential-helpers on GitHub](https://github.com/docker/docker-credential-helpers)
- [Secret Service API specification](https://specifications.freedesktop.org/secret-service-spec/)
- [Docker credential store documentation](https://docs.docker.com/reference/cli/docker/login/#credential-stores)
