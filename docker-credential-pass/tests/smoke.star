# Stable smoke test — assert on the credential-helper protocol contract, never
# on help/version prose.
#
# What this binary is FOR is storing a Docker registry credential in a
# `pass`-backed store, and that is precisely what CI cannot exercise: it needs
# the `pass` CLI, a GnuPG keypair and an initialised store on the host, none of
# which a mirror can bundle and none of which `containers[].setup` may provision
# (setup exists so the artifact can LOAD, it is not a pre-test hook).
#
# So this test asserts the part of the contract that is reachable with no store
# at all, and it is more than liveness. Measured against the real v0.9.8 binary
# on alpine:3.20 with neither `pass` nor `gpg` installed:
#
#   $ docker-credential-pass version   → exit 0, stdout "docker-credential-pass (…) v0.9.8"
#   $ docker-credential-pass list      → exit 0, stdout "{}"
#   $ printf '' | docker-credential-pass get
#                                      → exit 1, stdout "no credentials server URL"
#   $ docker-credential-pass bogus     → exit 1, "unknown action: bogus"
#
# Everything below is on STDOUT, not stderr — verified by splitting the streams
# rather than assuming, since `2>&1` hides which one spoke.
#
# Deliberately NOT asserted: the exact version string, and any message text
# beyond the two stable protocol tokens below. Deliberately NOT attempted: a
# store/get round-trip, which would need a provisioned host and would red for a
# reason that is not the artifact's fault.
HELPER = "docker-credential-pass"

# Tier 1 + 2: the binary loaded and ran under this platform's userland. On the
# alpine leg that is the ONLY evidence that the bare `linux/*` key — a positive
# claim that this artifact needs no particular libc — is honest.
#
# The version SHAPE is asserted, never the value.
r_version = ocx.run(HELPER, "version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"v\d+\.\d+\.\d+")

# IDENTITY. This repo publishes four helpers from one upstream release, all
# renamed by `asset_type.name` — so a mis-mapped asset regex would ship, say,
# the secretservice binary under this package's filename and every other
# assertion here would still pass. The program name in its own version banner is
# the one thing that distinguishes them, and it is a contract rather than prose:
# it is the literal value a user writes as `"credsStore"` in
# ~/.docker/config.json, so it cannot drift without breaking every consumer.
expect.contains(r_version.stdout, HELPER)

# Tier 3: the credential-helper wire protocol. `list` is the one verb that
# answers without a configured store, and it answers in JSON — so this proves
# the binary parsed its argv, reached the store layer, and emitted a well-formed
# result that `json.decode` accepts.
#
# The SHAPE is asserted, never the contents. `expect.eq(…, {})` was the first
# spelling and it is wrong: `list` reports whatever the HOST's password store
# holds, so it returns `{}` only on a machine that has none. It reds on any
# developer box with real `docker login` credentials in `pass` — caught by the
# mandatory local run before this ever reached CI, where the empty runner would
# have made it look correct forever.
r_list = ocx.run(HELPER, "list")
expect.ok(r_list)
expect.eq(type(json.decode(r_list.stdout)), "dict", msg = "list did not return a JSON object")

# Tier 3: `get` reads the server URL from STDIN, and rejects an empty one before
# it ever touches the keystore. That forces the stdin path to exist and to
# validate — a truncated or wrong-flavour binary cannot produce this pair of
# (exit 1, this token) — while needing no store, so it behaves identically on
# every platform this spec publishes.
r_empty = ocx.run(HELPER, "get", stdin = "")
expect.eq(r_empty.exit_code, 1, msg = "get accepted an empty server URL")
expect.contains(r_empty.stdout, "no credentials server URL")

# An unknown verb is refused rather than silently ignored. Cheap, and it is the
# assertion that would red if the rename ever landed a non-helper executable
# here that happened to exit 0 on anything.
r_bogus = ocx.run(HELPER, "definitely-not-an-action")
expect.eq(r_bogus.exit_code, 1, msg = "helper accepted an unknown action")
