# Stable smoke test — assert on the credential-helper protocol contract, never
# on help/version prose.
#
# This helper stores credentials through the freedesktop.org Secret Service
# D-Bus API, and that is exactly what CI cannot provide: a session bus with a
# provider (gnome-keyring, KWallet, KeePassXC) registered on
# `org.freedesktop.secrets`, unlocked. `containers[].setup` deliberately does
# not go there — it provisions the image so the artifact can LOAD, it is not a
# pre-test hook — so this script asserts the reachable part of the contract.
#
# That is still a real check, and the load half of it is the one that matters
# most for this package. Every assertion below runs AFTER the dynamic loader has
# resolved the full DT_NEEDED closure — libsecret-1, libgio-2.0, libgobject-2.0,
# libglib-2.0, libc — so a leg whose image lost libsecret, or an upstream that
# changed its link closure, reds here rather than shipping. Measured on the real
# v0.9.8 binary in ubuntu:24.04 with libsecret-1-0 installed and NO D-Bus:
#
#   $ docker-credential-secretservice version   → exit 0, stdout "…secretservice (…) v0.9.8"
#   $ printf '' | docker-credential-secretservice get
#                                               → exit 1, stdout "no credentials server URL"
#   $ docker-credential-secretservice nope      → exit 1, "unknown action: nope"
#
# And the same image WITHOUT libsecret installed dies before main with
#   error while loading shared libraries: libsecret-1.so.0
# which is what the `setup:` lines in ../mirror-base.yml exist to prevent.
#
# Everything below is on STDOUT, not stderr — verified by splitting the streams
# rather than assuming, since `2>&1` hides which one spoke.
#
# Deliberately NOT asserted: `list`, which DOES reach the store and therefore
# fails here with "Cannot spawn a message bus without a machine-id". Asserting
# that error would be asserting the absence of a keyring, not a property of this
# artifact — it would stay green if the binary were replaced with anything that
# also cannot reach D-Bus.
HELPER = "docker-credential-secretservice"

# Tier 1 + 2: the binary loaded — meaning the glibc loader found its interpreter
# AND every shared library in its closure — and ran to completion.
#
# The version SHAPE is asserted, never the value.
r_version = ocx.run(HELPER, "version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"v\d+\.\d+\.\d+")

# IDENTITY. This repo publishes four helpers from one upstream release, all
# renamed by `asset_type.name` — so a mis-mapped asset regex would ship, say,
# the statically linked `pass` binary under this package's filename, and it
# would sail through every other assertion here (it answers `version` and
# rejects an empty URL identically) while silently dropping the libsecret
# dependency this package's `+libc.glibc` keys and container `setup:` exist for.
# The program name in its own version banner is the one thing that separates
# them, and it is a contract rather than prose: it is the literal value a user
# writes as `"credsStore"` in ~/.docker/config.json.
expect.contains(r_version.stdout, HELPER)

# Tier 3: `get` reads the server URL from STDIN and rejects an empty one BEFORE
# it opens a D-Bus connection — which is why this assertion works on a bare
# runner while `list` cannot. It forces the stdin path to exist and to validate;
# a truncated or wrong-flavour binary cannot produce this pair of (exit 1, this
# token).
r_empty = ocx.run(HELPER, "get", stdin = "")
expect.eq(r_empty.exit_code, 1, msg = "get accepted an empty server URL")
expect.contains(r_empty.stdout, "no credentials server URL")

# An unknown verb is refused rather than silently ignored.
r_bogus = ocx.run(HELPER, "definitely-not-an-action")
expect.eq(r_bogus.exit_code, 1, msg = "helper accepted an unknown action")
