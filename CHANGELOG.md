# Changelog

All notable changes to CopyParty.app are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.2.0]: https://github.com/nyteshade/copyparty-gui/releases/tag/v1.2.0
[1.1.0]: https://github.com/nyteshade/copyparty-gui/releases/tag/v1.1.0
[1.0.0]: https://github.com/nyteshade/copyparty-gui/releases/tag/v1.0.0
