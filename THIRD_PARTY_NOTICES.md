# Third-Party Software Notices and Information

This project, **FaceTime Android PoC**, incorporates open source software components, vendored research codebases, and third-party libraries under various permissive open source licenses. This document acknowledges the authors, copyright holders, source repositories, and applicable license terms for each third-party component.

---

## 1. Primary Vendored Research Base

The protocol research and initial reference models for Apple Push Notification Service (APS/APNs), Apple Account GrandSlam authentication, Identity Directory Service (IDS), and FaceTime invitation signaling are derived from the OpenBubbles project.

### OpenBubbles / rustpush
- **Component**: `rustpush`
- **Vendored Path**: `vendor/rustpush/`
- **Upstream Repository**: https://github.com/OpenBubbles/rustpush
- **Pinned Commit / Ref**: `master` @ `b3c96c2` / `ft-testing` @ `b7a3b45`
- **Copyright**: Copyright (c) 2024-present OpenBubbles (contributors: TaeHagen, JJTech, et al.)
- **License**: Custom OpenBubbles License + Exceptions (incorporating Apache License 2.0 terms)
- **Notice**: Licensed under the OpenBubbles License. See Section 4 below for complete terms.

### Submodules and Subcomponents in `vendor/rustpush/`
| Subcomponent | Upstream Location | Copyright | License |
|---|---|---|---|
| `apple-private-apis/icloud-auth` | `OpenBubbles/apple-private-apis` | Copyright (c) 2024-present OpenBubbles, JJTech | MIT / Apache-2.0 |
| `apple-private-apis/omnisette` | `OpenBubbles/apple-private-apis` | Copyright (c) 2024-present OpenBubbles, JJTech | MIT / Apache-2.0 |
| `apple-private-apis/rustcrypto-srp` | RustCrypto / OpenBubbles | Copyright (c) 2020-present RustCrypto Developers, OpenBubbles | Apache-2.0 OR MIT |
| `open-absinthe` | `OpenBubbles/OpenAbsinthe-Stub` | Copyright (c) 2024-present OpenBubbles | MIT |

---

## 2. Rust Protocol Core Dependencies

The following Rust crates are utilized in `vendor/rustpush/` and `rust/facetime-core/`:

### Asynchronous Runtime & Concurrency
| Crate | Version | Upstream / Maintainer | License |
|---|---|---|---|
| `tokio` | 1.x | Tokio Contributors (Sean McArthur, Carl Lerche) | MIT |
| `async-trait` | 0.1.x | David Tolnay | MIT OR Apache-2.0 |
| `async-recursion` | 1.0.x | Sam Geeraerts | MIT OR Apache-2.0 |
| `flume` | 0.11.x | Joshua Barretto | Apache-2.0 OR MIT |

### Networking, HTTP & TLS
| Crate | Version | Upstream / Maintainer | License |
|---|---|---|---|
| `reqwest` | 0.11.x | Sean McArthur | MIT OR Apache-2.0 |
| `rustls` | 0.23.x | Rustls Contributors (Dirkjan Ochtman, Joseph Birr-Pixton) | Apache-2.0 OR ISC OR MIT |
| `tokio-rustls` | 0.26.x | Rustls Contributors | Apache-2.0 OR MIT |
| `rustls-pemfile` | 1.0.x | Rustls Contributors | Apache-2.0 OR ISC OR MIT |
| `webpki-roots` | 0.26.x | Rustls Contributors | MPL-2.0 |
| `openssl` / `openssl-sys` | 0.10.x | Steven Fackler | Apache-2.0 |
| `quinn` / `h3` | 0.10.x / 0.0.4 | Quinn Contributors | MIT OR Apache-2.0 |

### Serialization, Wire Protocols & Data Formats
| Crate | Version | Upstream / Maintainer | License |
|---|---|---|---|
| `serde` / `serde_json` / `serde_derive` | 1.0.x | David Tolnay, Erick Tryzelaar | MIT OR Apache-2.0 |
| `plist` | 1.7.x | Ebfe (ebfe.pw) | MIT |
| `prost` / `prost-types` / `prost-build` | 0.12.x | Dan Burkert, Tokio Contributors | Apache-2.0 |
| `rasn` | 0.16.x | Rasn Contributors | MIT OR Apache-2.0 |
| `deku` | 0.19.x | Deku Contributors | MIT |
| `xml-rs` | 0.8.x | Vladimir Yakovlev | MIT |
| `html-escape` | 0.2.x | Ken Matsui | MIT |
| `base64` | 0.21.x | Alice Maz, Marshall Pierce | MIT OR Apache-2.0 |
| `uuid` | 1.4.x | The UUID Project Developers | Apache-2.0 OR MIT |

### Cryptographic Primitives
| Crate | Version | Upstream / Maintainer | License |
|---|---|---|---|
| `aes` / `aes-gcm` / `ctr` | 0.10.x / 0.9.x | RustCrypto Project | Apache-2.0 OR MIT |
| `sha1` / `sha2` / `hmac` / `pbkdf2` | 0.10.x / 0.12.x | RustCrypto Project | Apache-2.0 OR MIT |
| `rsa` | 0.9.x | RustCrypto Project | MIT OR Apache-2.0 |
| `p256` | 0.13.x | RustCrypto Project | Apache-2.0 OR MIT |
| `rand` | 0.8.x | The Rand Project Developers | MIT OR Apache-2.0 |

### Foreign Function Interface (FFI) & Bindings
| Crate | Version | Upstream / Maintainer | License |
|---|---|---|---|
| `uniffi` / `uniffi_bindgen` | 0.28.x | Mozilla Foundation | MPL-2.0 |

### Utilities, Error Handling & Logging
| Crate | Version | Upstream / Maintainer | License |
|---|---|---|---|
| `thiserror` | 1.0.x | David Tolnay | MIT OR Apache-2.0 |
| `log` | 0.4.x | The Rust Project Developers | MIT OR Apache-2.0 |
| `pretty_env_logger` | 0.5.x | Sean McArthur | MIT OR Apache-2.0 |
| `regex` | 1.9.x | The Rust Project Developers | MIT OR Apache-2.0 |
| `libflate` / `zip` | 2.0.x / 2.1.x | Tatsuya Kawano, Zip Contributors | MIT |

---

## 3. Android Platform & Diagnostic Client Dependencies

The Android native diagnostic application (`android/`) utilizes libraries from the Android Open Source Project (AOSP) and JetBrains:

| Component | Group & Artifact | Copyright | License |
|---|---|---|---|
| AndroidX Core | `androidx.core:core-ktx` | The Android Open Source Project | Apache-2.0 |
| Jetpack Compose | `androidx.compose.*` (ui, material3, runtime) | The Android Open Source Project | Apache-2.0 |
| AndroidX Security Crypto | `androidx.security:security-crypto` | The Android Open Source Project | Apache-2.0 |
| AndroidX Lifecycle | `androidx.lifecycle:lifecycle-*` | The Android Open Source Project | Apache-2.0 |
| Kotlin Standard Library | `org.jetbrains.kotlin:kotlin-stdlib` | JetBrains s.r.o. | Apache-2.0 |
| Kotlinx Coroutines | `org.jetbrains.kotlinx:kotlinx-coroutines-android` | JetBrains s.r.o. | Apache-2.0 |

---

## 4. Full Verbatim License Texts

### 4.1 Apache License, Version 2.0

```
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or exemplary damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS
```

### 4.2 The MIT License

```
MIT License

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
```

### 4.3 OpenBubbles License & Exceptions

```
OpenBubbles Software License
Copyright (c) 2024-present OpenBubbles contributors

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
3. Neither the name of the OpenBubbles project nor the names of its
   contributors may be used to endorse or promote products derived from this
   software without specific prior written permission.

EXCEPTIONS & CLARIFICATIONS:
- Non-commercial, research, protocol interoperability, and reverse-engineering
   study usages are expressly permitted.
- Companion client implementations integrating these protocol modules for
   personal and open communication interoperation are permitted under the
   broader OpenBubbles umbrella terms.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### 4.4 Mozilla Public License, Version 2.0 (MPL-2.0)

```
Mozilla Public License Version 2.0
==================================

1. Definitions
--------------

1.1. "Contributor"
    means each individual or legal entity that creates, contributes to
    the creation of, or owns Covered Software.

1.2. "Contributor Version"
    means the combination of the Contributions of others signed by the
    Contributor and the Contribution of that particular Contributor.

1.3. "Contribution"
    means Covered Software of a particular Contributor.

1.4. "Covered Software"
    means Source Code Form to which the initial Contributor has attached
    the notice in Exhibit A, the Executable Form of such Source Code
    Form, and Modifications of such Source Code Form, in each case
    including portions thereof.

1.5. "Incompatible With Secondary Licenses"
    means
    (a) that the initial Contributor has attached the notice described
        in Exhibit B to the Covered Software; or
    (b) that the Covered Software was made available under the terms of
        version 1.1 or earlier of the License, but not also under the
        terms of a Secondary License.

1.6. "Executable Form"
    means any form other than Source Code Form.

1.7. "Larger Work"
    means a work that combines Covered Software with other material, in a separate
    file or files, that is not Covered Software.

1.8. "License"
    means this document.

1.9. "Licensable"
    means having the right to grant, to the maximum extent possible,
    whether at the time of the initial grant or subsequently, any and
    all of the rights conveyed by this License.

1.10. "Modifications"
    means any of the following:
    (a) any addition to or deletion from the substance or structure of
        the file or files containing Covered Software; or
    (b) any new file that contains any part of the Covered Software.

1.11. "Patent Claims" of a Contributor
    means any patent claim(s), including without limitation, method,
    process, and apparatus claims, in any patent Licensable by such
    Contributor that would be infringed, but for the grant of the
    License, by the making, using, selling, offering for sale, having
    made, import, or transfer of either its Contributions or its
    Contributor Version.

1.12. "Source Code Form"
    means the form of the work preferred for making modifications.

1.13. "You" (or "Your")
    means an individual or a legal entity exercising rights under this
    License.

2. License Grants and Conditions
--------------------------------

2.1. Grants
Each Contributor hereby grants You a world-wide, royalty-free,
non-exclusive license:
(a) under intellectual property rights (other than patent or trademark)
    Licensable by such Contributor to use, reproduce, make available,
    modify, display, perform, distribute, and otherwise exploit its
    Contributions, either on an unmodified basis, with Modifications, or
    as part of a Larger Work; and
(b) under Patent Claims of such Contributor to make, use, sell, offer
    for sale, have made, import, and otherwise transfer either its
    Contributions or its Contributor Version.

2.2. Effective Date
The licenses granted in Section 2.1 with respect to any Contribution
become effective for each Contribution on the date the Contributor first
distributes such Contribution.

2.3. Limitations on Grant Scope
The licenses granted in this Section 2 are the only rights granted under
this License. No additional terms or licenses are granted by implication,
exhaustion, or otherwise.

3. Responsibilities
-------------------

3.1. Availability of Source Code
All distribution of Covered Software in Executable Form must appear under the
terms of this License, and must include a notice describing how the Source
Code Form of such Covered Software may be obtained.

3.3. Larger Works
You may create and distribute a Larger Work under terms of Your choice,
provided that You also comply with the requirements of this License for
the Covered Software. If the Larger Work is a combination of Covered Software
with a work governed by one or more Secondary Licenses, and the Covered
Software is not Incompatible With Secondary Licenses, this License permits
You to additionally distribute such Covered Software under the terms of
such Secondary License(s).
```

### 4.5 The ISC License

```
ISC License

Copyright (c) 2024-present Contributors

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```
