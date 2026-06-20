# Security Policy

vaultwatch is a security tool, so its own correctness matters. It narrows the
channels through which plaintext from an *open* vault can leak and restores the
prior state when the vault closes — if it does that wrong, it could either leak
data it promised to contain or fail to put the system back as it found it. If you
find a vulnerability, please report it responsibly.

## Reporting a vulnerability

**Do not open a public issue for an exploitable vulnerability.**

Use GitHub's private vulnerability reporting:

1. Go to the repository's **Security** tab → **Report a vulnerability**
   (<https://github.com/Di-kairos/vaultwatch/security/advisories/new>).
2. Describe the issue, affected versions, and a reproduction if possible.

You'll get a response as soon as reasonably possible. Once a fix is ready, the
advisory is published and you'll be credited unless you prefer to stay anonymous.

## Scope

In scope:

- Anything that causes vaultwatch to **claim a guarantee it does not provide**
  (the project's whole point is honesty about what an open vault can leak).
- **Incorrect restore on `stop`:** failing to re-enable Spotlight indexing or to
  remove a Time Machine exclusion that *this session* added, leaving the system
  in a weaker state than it found it.
- **Touching state it did not own:** "fixing" Spotlight or a Time Machine
  exclusion that was already off/excluded before the session — `stop` must
  restore only what `start` changed.
- **Unsafe auto-detach (`--ttl`):** unmounting a vault with open file
  descriptors without the documented `lsof` check and confirmation, or any path
  that could lose data on `hdiutil detach -force`.
- Privilege or injection issues in the shell code, the `install.sh` installer,
  the vendored common block, or the launchd LaunchAgent plist that drives `--ttl`.
- Hook handling in `install-hooks` / `uninstall-hooks` that could clobber or run
  hooks vaultwatch does not own.

Out of scope:

- **Swap is not addressed.** If memory pressure pushed plaintext fragments into
  swap during a session, they may remain until overwritten. This is the honest
  premise, documented in the README "Scope & limitations" and the session
  report — not a bug.
- **Pre-existing Time Machine local snapshots** taken before `start`. vaultwatch
  excludes the vault going forward and *detects and reports* earlier snapshots
  (`tmutil listlocalsnapshots /`); it deliberately does not delete them.
- **Cloud sync.** Cloud detection is heuristic (running daemons +
  inside/outside their sync folder). vaultwatch does not edit cloud settings or
  remove already-uploaded copies, and never claims to.
- Leaks that occur while the vault is **closed** — vaultwatch is active only
  while the vault is mounted, by design.

## Supported versions

The latest released version receives security fixes. vaultwatch is pre-1.0;
older tags are not maintained.
