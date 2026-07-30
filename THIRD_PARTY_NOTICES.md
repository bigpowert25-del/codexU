# Third-Party Notices

## Upstream codexU

This customized build is based on codexU v1.0.5.

- Source: https://github.com/shanggqm/codexU
- Original author: Guomeiqing
- License: MIT

The upstream copyright and MIT license text are preserved in `LICENSE`.

The Claude Code provider and `Resources/claudecode-*.png` assets were restored
from the upstream codexU v1.0.5 source. Claude Code is an Anthropic product;
all related names and marks belong to their respective owners. This project is
not affiliated with or endorsed by Anthropic.

## OpenClaw

The OpenClaw runtime logo assets in `Resources/openclaw-color.png` and
`Resources/openclaw-template.png` are derived from the locally installed
OpenClaw distribution.

- Source: https://github.com/openclaw/openclaw
- Installed reference version: 2026.6.1
- License: MIT

MIT License

Copyright (c) 2026 OpenClaw Foundation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Dynamic Island inspiration and local prototype

The local Dynamic Island prototype reuses or adapts ideas from the following
open-source projects:

- CodexIsland by Eric Park: https://github.com/ericjypark/codex-island
  - License: MIT
  - Used as a reference for a native macOS Codex usage island, compact / peek /
    expanded presentation, and local-first usage display patterns.
- Ping Island by erha19: https://github.com/erha19/ping-island
  - License: Apache License 2.0
  - Used as a reference for multi-agent session/status modeling, attention-first
    sorting, and Codex/OpenClaw/Hermes-style provider surfaces.
- Dynamic Island for Windows by sadeeshasathsara:
  https://github.com/sadeeshasathsara/dynamic-island-on-windows
  - License: MIT
  - Copied into `WindowsIsland/` as the Windows WPF prototype base, then renamed
    and adapted for codexU local JSON snapshots. The copied folder retains its
    original `LICENSE`.

The following projects were reviewed but treated as reference-only for
public-safe code in this repository:

- eIsland by JNTMTMTM: GPLv3 with additional clauses and platform restriction.
- MioIsland by MioMioOS: CC BY-NC 4.0.
- Python-island/Python-island: no root license file found in the reviewed clone.
- rajsriv/dynamic-island-for-windows: README links MIT, but no `LICENSE` file
  was present in the reviewed clone.

## Hermes Agent

The Hermes runtime integration follows the default-profile session database
format documented and implemented by Nous Research's Hermes Agent. The color
logo in `Resources/hermes-color.png` is cropped and resized from the official
`apps/desktop/public/hermes.png`; `Resources/hermes-template.png` is a derived
monochrome alpha template for the macOS menu bar.

- Source: https://github.com/NousResearch/hermes-agent
- Session storage documentation: https://github.com/NousResearch/hermes-agent/blob/main/website/docs/developer-guide/session-storage.md
- Original logo path: `apps/desktop/public/hermes.png`
- Original downloaded asset SHA-256: `5e13476656a8890876fb3e021ac431de7e393461f3893c64b6311e61e60f266d`
- License: MIT

MIT License

Copyright (c) 2025 Nous Research

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Model Context Protocol Swift SDK and transitive packages

The bundled `GodexUMCPServer` executable is built with the official Model
Context Protocol Swift SDK. Exact versions and source revisions are locked in
`MCPHelper/Package.resolved`.

- Model Context Protocol Swift SDK 0.12.1:
  https://github.com/modelcontextprotocol/swift-sdk
  - License: licensing transition; applicable code is Apache-2.0 or MIT as
    described by the upstream `LICENSE`.
- EventSource 1.4.1: https://github.com/mattt/eventsource
  - License: MIT.
- Swift Atomics 1.3.1: https://github.com/apple/swift-atomics
  - License: Apache-2.0.
- Swift Collections 1.6.0: https://github.com/apple/swift-collections
  - License: Apache-2.0.
- Swift Log 1.14.0: https://github.com/apple/swift-log
  - License: Apache-2.0. Its notice credits SwiftNIO-derived locking and build
    scripts.
- SwiftNIO 2.101.3: https://github.com/apple/swift-nio
  - License: Apache-2.0. Its upstream notice also identifies included or
    derived work from Netty, NodeJS llhttp, uSHET, FreeBSD, Swift Base64,
    AsyncHTTPClient, Swift Certificates, Swift System, and Swift Package
    Manager under their respective Apache-2.0, MIT, or BSD-3-Clause terms.
- Swift System 1.7.5: https://github.com/apple/swift-system
  - License: Apache-2.0.

The Apache License 2.0 is available at
https://www.apache.org/licenses/LICENSE-2.0. The MIT license text applicable to
this repository is preserved in `LICENSE`; package-specific copyright notices
remain in the linked upstream license files. No affiliation or endorsement by
the Model Context Protocol project or Apple is implied.
