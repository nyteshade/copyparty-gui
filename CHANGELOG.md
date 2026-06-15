# Changelog

All notable changes to CopyParty.app are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.1] — 2026-06-14

First properly distributable release — signed, notarized, and shipped in three
flavors so it runs cleanly on any Mac.

### Added

- **Notarized distributables** — `scripts/build-release.sh` builds a Developer ID
  signed, hardened-runtime app, deep-signs every embedded Mach-O (the bundled
  CPython runtime + native extensions) inside-out, submits it to Apple's notary
  service, staples the ticket, and packages a `.dmg` and `.zip`.
- **Universal (Intel + Apple Silicon) builds** — `scripts/fetch-vendor.sh` can now
  assemble a universal `Vendor/python` by fetching both architectures of
  python-build-standalone and `lipo`-merging every Mach-O; `scripts/thin-vendor.sh`
  thins a universal runtime back to a single arch.
- **One-command release** — `scripts/release-github.sh` produces three flavors and
  publishes a GitHub release with notes:
  - **universal** (notarized) — runs on any Mac, zero Gatekeeper friction;
  - **arm64** (notarized) — Apple Silicon only, smaller download;
  - **adhoc** (ad-hoc signed, not notarized) — for self-builders / offline use,
    runs after clearing quarantine.

### Changed

- No functional changes to the app itself versus 1.5.0; this release is about
  signing, notarization, and distribution.

## [1.5.0] — 2026-06-14

A full visual + interaction pass.

### Added

- **Themed UI** — a glossy, full-height 80s-cassette-yellow sidebar (color and
  artwork derived from the app icon) with a left→right "lit plastic" gradient,
  a neutral light/dark detail pane, cobalt accents, and a translucent oversized
  cassette watermark bleeding off the southeast corner (more solid in light
  mode).
- **APCA-style contrast** — text/background pairs are tuned for real lightness
  contrast (light surface → dark ink, dark surface → light ink), so labels stay
  crisp in both appearances instead of relying on WCAG-passing midtone grays.
- **Custom segmented control** for the detail tabs (crisper labels and standard
  spacing than the system picker).
- **Access permission chips** with obvious active/inactive states and an instant
  on-hover label (e.g. `R — Read`) so meaning shows without waiting for a tooltip.
- **Custom sidebar collapse control** that lives in the sidebar when open and
  moves to the detail header when collapsed.

### Fixed

- **No more accidental renames / keystroke theft** — the window no longer
  auto-focuses a text field when it becomes key. The server name is a label;
  rename via double-click or the pencil.
- **Full-height sidebar restored on macOS 26** — keep the native sidebar toggle
  (removing it flips the sidebar to an inset floating panel) and hide its button
  view in AppKit instead, so the yellow runs full-height under the titlebar.
- **Status badge & engine pill contrast** on the yellow sidebar; unified Log
  header font sizes; off-main-thread version probe (no UI hitch).

## [1.4.0] — 2026-06-14

### Added

- **Port-conflict resolution.** Starting a server now checks every port first; if
  one is busy, an alert offers to switch to the next free port(s) and start
  (**Fix & Start**) instead of just failing. Auto-start servers resolve conflicts
  automatically at launch and note the change in the log.

### Fixed

- **Child copyparty processes no longer orphan when the app quits.** SwiftUI's
  cleanup hooks don't run on SIGTERM (e.g. `pkill`), so a running server could
  survive the app and keep its port bound. A new `ProcessReaper` tracks every
  child PID, terminates them on quit / SIGTERM / SIGINT, and reaps leftovers from
  a previous hard-killed run on the next launch. It only ever signals processes
  whose command line is unmistakably our own copyparty (matches both
  `copyparty-sfx.py` and a `CopyParty.app` bundle path), so it can never kill an
  unrelated process — even on PID reuse.

## [1.3.0] — 2026-06-14

### Fixed

- **A failing protocol no longer crashes the whole server.** copyparty aborts the
  entire process if any single listener can't bind, so enabling e.g. SMB on a
  taken port took everything down. The app now pre-flights every planned port
  (HTTP/FTP/FTPS/SFTP/TFTP/SMB) before launching and refuses to start with a
  clear message naming the conflicting port, instead of letting copyparty crash.

### Changed

- **SMB now defaults to port 3945** instead of 445. macOS already owns 445 (file
  sharing) and binding it requires root; connect with `smb://host:3945`. The
  pre-flight check also calls out privileged ports (<1024) that need root.

## [1.2.0] — 2026-06-14

### Added

- **Visible update indicator** — an always-on engine status pill in the sidebar
  shows the installed copyparty version and update state at a glance (idle /
  checking / up-to-date / update available / downloading / installed / error),
  with a details popover (installed vs. latest version, last-checked time, and
  Check Now / Update / release-notes actions). The app performs one quiet update
  check on launch.
- **Licensing** — `LICENSE` (MIT, for the source code) and `NOTICE` (clarifying
  that the CC BY-NC-SA app icon and bundled third-party components keep their own
  terms).

### Fixed

- The copyparty version probe now runs off the main thread, so refreshing the
  version no longer briefly blocks the UI.

## [1.1.0] — 2026-06-14

### Added

- **Unmasked Dock icon** — on launch the app sets its Dock icon programmatically
  from the raw `A-Side.icns`, bypassing the macOS 26 ("Tahoe") squircle mask so
  the full-bleed cassette artwork renders correctly. Older macOS keeps using the
  bundle's app icon unchanged.

### Changed

- README expanded to complete coverage of features, protocols, configuration,
  building, and troubleshooting.

## [1.0.0] — 2026-06-14

First release. A native macOS GUI for the
[copyparty](https://github.com/9001/copyparty) file server with a fully
self-contained, batteries-included Python runtime.

### Added

- **Self-contained runtime** — bundles a relocatable CPython 3.12.13
  ([python-build-standalone](https://github.com/astral-sh/python-build-standalone))
  and copyparty-sfx.py 1.20.16 inside the `.app`; no system Python required.
- **Fully-featured engine** — the bundled Python ships copyparty's optional
  dependencies so every protocol/feature works out of the box:
  - `paramiko` → SFTP
  - `Pillow` → image thumbnails
  - `mutagen` → media tag indexing
  - `impacket` → SMB
  - `argon2-cffi` → argon2 password hashing
- **Multiple server instances** — each runs as its own copyparty process with
  its own ports, so different directories can be served on different ports
  simultaneously.
- **Per-server volumes** — mount any number of directories, each with its own
  URL path, per-user access rules (read / write / move / delete / get / upget /
  admin), and volflags.
- **Protocol coverage** — HTTP, HTTPS, WebDAV, FTP, FTPS, SFTP, TFTP, SMB,
  Zeroconf/mDNS discovery, and console QR codes, all configurable in the UI.
- **User management** — define accounts and grant them granular per-volume
  permissions.
- **Save / load configurations** — Export one or all servers to a portable,
  versioned JSON bundle (a single file can carry several servers, each with
  multiple endpoints) and import setups back in. Available from the File menu
  and the sidebar context menu.
- **Live log console** streaming each server's stdout/stderr.
- **copyparty update checker** — compares the bundled version against the latest
  GitHub release, with semantic version comparison and in-place download of a
  newer copyparty-sfx.py.
- **Custom About window** with version, copyright, and full icon attribution.
- **App icon** generated from the "A-Side" cassette artwork.

### Credits

- Directed and co-authored using Anthropic's Claude Opus 4.8.
- App icon: "A-Side" cassette tape icon by
  [barkerbaggies](https://www.deviantart.com/barkerbaggies), licensed under
  [CC BY-NC-SA 3.0 Unported](https://creativecommons.org/licenses/by-nc-sa/3.0/).

[1.5.0]: https://github.com/nyteshade/copyparty-gui/releases/tag/v1.5.0
[1.4.0]: https://github.com/nyteshade/copyparty-gui/releases/tag/v1.4.0
[1.3.0]: https://github.com/nyteshade/copyparty-gui/releases/tag/v1.3.0
[1.2.0]: https://github.com/nyteshade/copyparty-gui/releases/tag/v1.2.0
[1.1.0]: https://github.com/nyteshade/copyparty-gui/releases/tag/v1.1.0
[1.0.0]: https://github.com/nyteshade/copyparty-gui/releases/tag/v1.0.0
