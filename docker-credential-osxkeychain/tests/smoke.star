# Stable smoke test — assert on the credential-helper protocol contract, never
# on help/version prose.
#
# This helper stores credentials in the macOS login Keychain via Keychain
# Services. Unlike its `pass` and `secretservice` siblings it needs nothing
# installed on the host — the Keychain is an OS service — but a GitHub macOS
# runner's login keychain is still not a keystore this test should touch.
#
# So `list` is deliberately NOT asserted here, though the sibling `pass` spec
# does assert it. Two reasons, and the second is the real one:
#
#   1. It reads HOST state — whatever the runner's keychain happens to hold —
#      so any assertion on its contents tests the runner, not the artifact.
#      (That exact bug was caught in the pass spec by the mandatory local run.)
#   2. Reaching Keychain Services on a CI runner can block on an access-control
#      prompt against a locked keychain. A smoke that can HANG is worse than one
#      that asserts less: it burns a 10x-cost macOS leg and reds as a timeout
#      naming nothing.
#
# What is asserted instead runs entirely before any keystore call, so it is
# platform-independent — the same three checks pass on the linux siblings, which
# is how they were verified against a real bundle before ever reaching a macOS
# runner. Measured on the real v0.9.8 binaries:
#
#   $ docker-credential-<helper> version   → exit 0, stdout "…-<helper> (…) v0.9.8"
#   $ printf '' | docker-credential-<helper> get
#                                          → exit 1, stdout "no credentials server URL"
#   $ docker-credential-<helper> nope      → exit 1, "unknown action: nope"
#
# Everything below is on STDOUT, not stderr — verified by splitting the streams
# rather than assuming, since `2>&1` hides which one spoke.
HELPER = "docker-credential-osxkeychain"

# Tier 1 + 2: the binary loaded and ran. `NOUNDEFS` in the Mach-O header says
# every symbol resolved at link time, and the dynamic closure is
# Security.framework / CoreFoundation / libresolv / libSystem — all OS-provided
# — so this reaching exit 0 is also the evidence that no host provisioning is
# required, which is the claim this package's CATALOG.md makes.
#
# The version SHAPE is asserted, never the value.
r_version = ocx.run(HELPER, "version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"v\d+\.\d+\.\d+")

# IDENTITY. This repo publishes four helpers from one upstream release, all
# renamed by `asset_type.name` — and `pass` ships darwin assets too, so a
# mis-anchored regex here would land the WRONG helper on this platform and every
# other assertion in this file would still pass. The program name in its own
# version banner is the one thing that separates them, and it is a contract
# rather than prose: it is the literal value a user writes as `"credsStore"` in
# ~/.docker/config.json.
expect.contains(r_version.stdout, HELPER)

# Tier 3: `get` reads the server URL from STDIN and rejects an empty one BEFORE
# it opens the Keychain — which is why this assertion is safe on a runner while
# `list` is not. It forces the stdin path to exist and to validate; a truncated
# or wrong-flavour binary cannot produce this pair of (exit 1, this token).
r_empty = ocx.run(HELPER, "get", stdin = "")
expect.eq(r_empty.exit_code, 1, msg = "get accepted an empty server URL")
expect.contains(r_empty.stdout, "no credentials server URL")

# An unknown verb is refused rather than silently ignored.
r_bogus = ocx.run(HELPER, "definitely-not-an-action")
expect.eq(r_bogus.exit_code, 1, msg = "helper accepted an unknown action")
