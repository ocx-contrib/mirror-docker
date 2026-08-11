---
title: docker-credential-pass
description: Docker credential helper backed by pass — keeps registry credentials out of a plaintext config.json, in a GnuPG-encrypted password store. Static binary, works headless.
keywords: docker,credential-helper,pass,gnupg,gpg,registry,credentials,credsstore,docker-login,keychain,headless,ci
---

# docker-credential-pass

A credential helper keeps your registry passwords **out of
`~/.docker/config.json`**, where they otherwise sit base64-encoded — obfuscated,
not encrypted, readable by anything that can read the file. `docker login` and
everything else that speaks Docker's credential-store protocol hands the
credential to a helper instead, which stores it in a real keystore.

This one is the **`pass` backend**: credentials go into a
[`pass`](https://www.passwordstore.org/) password store, encrypted with your
GnuPG key. It is the backend that works **headless** — no desktop session, no
D-Bus, no login keychain — which makes it the right choice on servers, in
containers, and on any machine you reach over SSH.

OCX's own registry auth reads the Docker credential store too, so this is the
helper that secures `ocx`'s credentials as well as Docker's.

## ⚠️ Requires `pass` and GnuPG on the host

This package ships **one statically linked binary and nothing else**. The binary
itself needs no libraries at all, but at runtime it shells out to the `pass`
command, which in turn needs `gpg`. Neither can be bundled inside an OCX
package — install them with your system package manager:

| System | Install |
|---|---|
| Debian / Ubuntu | `sudo apt-get update && sudo apt-get install -y pass` |
| Fedora / RHEL / CentOS | `sudo dnf install -y pass` |
| Arch | `sudo pacman -S --needed pass` |
| Alpine | `sudo apk add pass` |
| macOS (Homebrew) | `brew install pass` |

`gpg` arrives as a dependency of `pass` on every one of the above, so the single
command is enough.

Then initialise the store once — `pass` cannot encrypt anything until a GnuPG
key exists and the store is pointed at it:

```sh
gpg --full-generate-key    # accept the defaults, set a passphrase
pass init "$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10; exit}')"
```

Without that, `docker login` fails when it calls the helper. The helper's own
`version` and `list` verbs answer regardless, so a working `version` is not
evidence the store is set up. To check that it really is, round-trip a throwaway
credential:

```sh
echo '{"ServerURL":"https://example.org","Username":"alice","Secret":"s3cr3t"}' \
  | docker-credential-pass store
docker-credential-pass list          # → {"https://example.org":"alice"}
```

## What's included

- **docker-credential-pass** — the single static binary. Docker resolves it from
  `PATH` by this exact name; do not rename it.

## Usage

Point Docker at the helper by setting `credsStore` in `~/.docker/config.json` —
the value is the helper's name **minus** the `docker-credential-` prefix:

```json
{
  "credsStore": "pass"
}
```

From then on `docker login` writes to the password store instead of the config
file, and `docker pull` reads back out of it. Existing plaintext `auths` entries
are not migrated — run `docker logout <registry>` and log in again to move them.

The helper also speaks its protocol directly, which is useful for scripting and
for checking your setup:

```sh
docker-credential-pass list                      # → {"https://index.docker.io/v1/":"you"}
echo "https://index.docker.io/v1/" | docker-credential-pass get
```

Sibling backends ship from the same upstream release — **docker-credential-secretservice**
for a Linux desktop with a D-Bus Secret Service, **docker-credential-osxkeychain**
for the macOS login Keychain, and **docker-credential-wincred** for Windows
Credential Manager. Each is one `ocx add` away.

## Links

MIT licensed.

- [docker-credential-helpers on GitHub](https://github.com/docker/docker-credential-helpers)
- [pass — the standard unix password manager](https://www.passwordstore.org/)
- [Docker credential store documentation](https://docs.docker.com/reference/cli/docker/login/#credential-stores)
