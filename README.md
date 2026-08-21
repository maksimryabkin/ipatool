# ipatool-sapfix

[![Release](https://img.shields.io/github/v/release/maksimryabkin/ipatool-sapfix?include_prereleases&label=release)](https://github.com/maksimryabkin/ipatool-sapfix/releases)
[![License](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

A macOS-focused community build of [`ipatool`](https://github.com/majd/ipatool)
that restores Apple App Store authentication after login requests started failing
with:

```text
request failed: unexpected response from Apple (HTTP 403): empty or non-plist body
```

The fix adds Apple's required SAP action signature
(`X-Apple-ActionSignature`) through the macOS CommerceKit service. It also keeps
passwords and two-factor authentication codes out of verbose logs.

This is an unofficial community project. It is not affiliated with Apple or the
upstream `ipatool` maintainers.

## Download

Download the current prerelease from the
[Releases page](https://github.com/maksimryabkin/ipatool-sapfix/releases/tag/2.3.2-sapfix.1).

| Mac | `uname -m` | Archive |
| --- | --- | --- |
| Apple Silicon | `arm64` | `ipatool-2.3.2-sapfix.1-macos-arm64.tar.gz` |
| Intel | `x86_64` | `ipatool-2.3.2-sapfix.1-macos-amd64.tar.gz` |

Each archive has a matching `.sha256sum` file attached to the release.

## Install

Apple Silicon example:

```shell
shasum -a 256 -c ipatool-2.3.2-sapfix.1-macos-arm64.tar.gz.sha256sum
tar -xzf ipatool-2.3.2-sapfix.1-macos-arm64.tar.gz
sudo install -m 0755 \
  bin/ipatool-2.3.2-sapfix.1-macos-arm64 \
  /usr/local/bin/ipatool
ipatool --version
```

For an Intel Mac, replace `arm64` with `amd64` in the archive and binary names.

If macOS reports that the downloaded binary cannot be opened, verify the
checksum first and then remove only its quarantine attribute:

```shell
xattr -d com.apple.quarantine bin/ipatool-2.3.2-sapfix.1-macos-arm64
```

## Use

Log in interactively so the password is read from the prompt rather than from
the shell command line:

```shell
ipatool auth login --email "you@example.com"
```

Then search for, acquire, and download an app:

```shell
ipatool search "Example App"
ipatool purchase --bundle-identifier com.example.app
ipatool download --bundle-identifier com.example.app \
  --output ExampleApp.ipa
```

Run `ipatool --help` or `ipatool <command> --help` for all available options.

## Requirements and limitations

- App Store authentication in this build requires macOS with cgo enabled.
- Release binaries are provided for Apple Silicon and Intel Macs.
- The App Store protocol is private and can change without notice.
- Downloaded App Store packages remain encrypted and are tied to the Apple ID
  that acquired them.
- You are responsible for following Apple's terms and applicable law.

## Build from source

Install a recent Go toolchain and the Xcode command line tools, then run:

```shell
git clone https://github.com/maksimryabkin/ipatool-sapfix.git
cd ipatool-sapfix
CGO_ENABLED=1 go build -trimpath -o ipatool .
./ipatool --version
```

## Security and privacy

The repository and release artifacts contain no Apple ID, password, two-factor
code, session token, or local build path. GitHub secret scanning and push
protection are enabled for the public repository.

Do not publish raw authentication logs. If you report a bug, redact email
addresses, tokens, cookies, DSIDs, passwords, and two-factor codes first.

## Credits and license

Based on [`majd/ipatool`](https://github.com/majd/ipatool) and distributed under
the [MIT License](LICENSE). The original copyright and license notice are
preserved.
