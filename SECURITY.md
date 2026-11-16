# Security

OpenTTDPad is an offline game with optional network features inherited from
OpenTTD: Online Content downloads over verified HTTPS and multiplayer.

- **A problem in the iPad layer** (`engine/src/os/ios/`, Files import, URL
  handling, the bundled CA store): report it privately through
  [GitHub's private vulnerability reporting](https://github.com/chrissotraidis/OpenTTDPad/security/advisories/new).
- **A problem in OpenTTD itself** (networking, savegame parsing, scripts): report
  it to OpenTTD as described in their
  [security policy](https://github.com/OpenTTD/OpenTTD/security/policy); fixes
  arrive here with the next upstream update.

Only the latest release is supported.
