# Warcraft III: Reforged 3.0 login fix for GE-Proton ("Please check your VPN")

Since the September 2026 3.0 expansion update, Warcraft III: Reforged fails to log in under
Proton / GE-Proton with:

> There was an error in handling the request. Please check your VPN

This repo contains a rebuilt `crypt32.dll` for GE-Proton 11-6 that fixes it, the source patch,
and an install script.

## Quick install (Steam, Battle.net as a non-Steam game)

Requires GE-Proton 11-6 already installed in `~/.steam/root/compatibilitytools.d/GE-Proton11-6-x86_64`
(download from https://github.com/GloriousEggroll/proton-ge-custom/releases/tag/GE-Proton11-6 if needed).

```bash
git clone https://github.com/FerMPY/wc3-reforged-proton-fix
cd wc3-reforged-proton-fix
./install.sh
# or pass `--proton-plus` to target default proton plus directory
./install.sh --proton-plus
```

Then restart Steam, open Battle.net Launcher.exe → Properties → Compatibility, and select
**GE-Proton11-6-wc3fix**. Launch Warcraft III from Battle.net as usual.

The script copies your GE-Proton 11-6 into a new tool and replaces only
`files/lib/wine/x86_64-windows/crypt32.dll` and `files/lib/wine/i386-windows/crypt32.dll`.
Your original GE-Proton is not modified.

## The cause

The 3.0 update shipped a new `ClientSdk.dll` (Blizzard's networking/auth library). After the TLS
handshake with Battle.net it validates the server certificate through Windows crypto and calls
`CertCreateCertificateChainEngine()` with the current `CERT_CHAIN_ENGINE_CONFIG` struct, which is
88 bytes on 64-bit (it includes the `dwExclusiveFlags` field added in Windows 8).

Proton's Wine (GE-Proton 11.x and Valve Proton, both based on Wine 11.0) only accepts the two older
layouts of that struct, 64 and 80 bytes, and rejects anything else with `E_INVALIDARG`. The game
cannot build a certificate chain engine, treats the connection as untrusted and reports it as a
VPN problem.

Upstream Wine fixed this in April 2026 (Wine 11.6):

- `02bb0a34` crypt32: Trace CERT_CHAIN_ENGINE_CONFIG fields in CertCreateCertificateChainEngine().
- `eef8e97d` crypt32: Don't access CERT_CHAIN_ENGINE_CONFIG::dwExclusiveFlags without checking size.
- `c7cc9be8` crypt32: Also accept CERT_CHAIN_ENGINE_CONFIG without dwExclusiveFlags.

Proton has not rebased onto a Wine containing them yet. Plain Wine 11.6 or newer (e.g. recent
wine-staging / wine-tkg builds in Lutris) already works.

## How the DLLs were built

- Source: ValveSoftware/wine at commit `9358696fe9a2261329f4a83aa6a65fd436106154` (the wine
  submodule of GE-Proton 11-6).
- Applied `crypt32-chain-engine-config-88.patch` (backport of the three commits above plus the
  `include/wincrypt.h` change).
- Cross-compiled in a Fedora 42 container with MinGW GCC 14.2.1:

```bash
autoreconf -f
mkdir out && cd out
../wine/configure --enable-archs=i386,x86_64 --disable-tests --without-x --without-freetype \
  --without-vulkan --without-opengl --without-gstreamer --without-gnutls ...
make dlls/crypt32/x86_64-windows/crypt32.dll dlls/crypt32/i386-windows/crypt32.dll
```

Only crypt32.dll changes; the Unix-side `crypt32.so` and everything else stay as shipped by GE.

## How it was diagnosed

Ran the game through Steam with `PROTON_LOG=1 WINEDEBUG=+winsock,+iphlpapi,+secur32 %command%`.
The trace showed every TLS handshake completing, the game requesting the remote certificate
(`SECPKG_ATTR_REMOTE_CERT_CONTEXT`) and then immediately closing the connection. `ClientSdk.dll`
imports `CertCreateCertificateChainEngine`; comparing Proton's `dlls/crypt32/chain.c` and
`include/wincrypt.h` against upstream Wine showed the 64/80 vs 88-byte size check.
