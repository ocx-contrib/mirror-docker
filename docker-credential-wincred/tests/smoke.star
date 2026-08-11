# Stable smoke test — assert on the credential-helper protocol contract, never
# on help/version prose.
#
# This helper stores credentials in Windows Credential Manager through the
# platform API. Like its osxkeychain sibling it needs nothing installed on the
# host, but a GitHub Windows runner's credential store is still not a keystore
# this test should touch: `list` reads HOST state, so any assertion on its
# contents tests the runner rather than the artifact. (That exact bug was caught
# in the `pass` spec by the mandatory local run, where `list` returned a real
# developer's stored logins instead of the empty map the assertion expected.)
#
# So what is asserted here runs entirely before any keystore call, which also
# makes it platform-independent — the same three checks pass on the Linux
# siblings, and that is how they were verified against a real bundle before ever
# reaching a Windows runner. Measured on the real v0.9.8 binaries:
#
#   $ docker-credential-<helper> version   → exit 0, stdout "…-<helper> (…) v0.9.8"
#   $ printf '' | docker-credential-<helper> get
#                                          → exit 1, stdout "no credentials server URL"
#   $ docker-credential-<helper> nope      → exit 1, "unknown action: nope"
#
# Everything below is on STDOUT, not stderr — verified by splitting the streams
# rather than assuming, since `2>&1` hides which one spoke.

# `.exe` spelled out rather than branched on `ocx.target_platform.os`: this spec
# publishes Windows and nothing else, so a ternary here would carry a branch
# that can never be taken. The name matches `asset_type.name` in mirror.yml,
# which is what the bundle actually contains.
#
# Note this is the ONE place the `.exe` appears in the test surface — the
# `binaries` claim in metadata.json is the bare `docker-credential-wincred`,
# which is correct: that is the interface name, and it is also how Docker
# resolves the helper, with PATHEXT supplying the extension.
HELPER = "docker-credential-wincred.exe"

# Tier 1 + 2: the binary loaded and ran. Reaching exit 0 with nothing installed
# on the runner is also the evidence for the claim this package's CATALOG.md
# makes — that Credential Manager is an OS service and needs no provisioning.
#
# The version SHAPE is asserted, never the value.
r_version = ocx.run(HELPER, "version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"v\d+\.\d+\.\d+")

# IDENTITY. This repo publishes four helpers from one upstream release, all
# renamed by `asset_type.name` — so a mis-mapped asset regex would ship the
# wrong one under this package's filename and every other assertion here would
# still pass. The program name in its own version banner is the one thing that
# separates them, and it is a contract rather than prose: it is the literal
# value a user writes as `"credsStore"` in ~/.docker/config.json.
#
# Matched WITHOUT the `.exe` — the banner prints the program's own name, which
# carries no extension.
expect.contains(r_version.stdout, "docker-credential-wincred")

# Tier 3: `get` reads the server URL from STDIN and rejects an empty one BEFORE
# it opens Credential Manager — which is why this assertion is safe on a runner
# while `list` is not. It forces the stdin path to exist and to validate; a
# truncated or wrong-flavour binary cannot produce this pair of (exit 1, this
# token).
r_empty = ocx.run(HELPER, "get", stdin = "")
expect.eq(r_empty.exit_code, 1, msg = "get accepted an empty server URL")
expect.contains(r_empty.stdout, "no credentials server URL")

# An unknown verb is refused rather than silently ignored.
r_bogus = ocx.run(HELPER, "definitely-not-an-action")
expect.eq(r_bogus.exit_code, 1, msg = "helper accepted an unknown action")
