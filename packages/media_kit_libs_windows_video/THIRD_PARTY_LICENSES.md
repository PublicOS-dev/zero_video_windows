# Third-party licenses

This package ships prebuilt native libraries. Their licenses are **not** the MIT
license that covers the CMake and Dart code here. An application bundling this
package must honour the terms below.

## libmpv (`libmpv-2.dll`)

- **Version:** mpv `v0.36.0-403-g652a1dd907`
- **Build:** `-Dgpl=false` → **LGPL** (mpv is GPLv2+ by default; this build is not)
- **Bundled FFmpeg:** configured `--disable-gpl --disable-nonfree --enable-version3`.
  `libavcodec`, `libavformat`, `libavutil`, `libavfilter`, `libswresample` and
  `libswscale` each self-report **"LGPL version 3 or later"**.
- **Effective license:** **LGPLv3**. No GPL or non-free component.
- **Source:** <https://github.com/media-kit/libmpv-win32-video-build> (release
  `2023-09-24`; repository archived October 2024)
- Upstream sources: <https://github.com/mpv-player/mpv> · <https://ffmpeg.org>

Also statically linked inside `libmpv-2.dll` (all permissive or LGPL-compatible):
dav1d, libass, freetype, fribidi, libwebp, libjxl, zimg, soxr, speex, mbedTLS,
libxml2, bs2b, libmysofa, shaderc.

### Obligations for a closed-source application

LGPLv3 permits linking from proprietary software provided the user can replace
the library. This is satisfied **as shipped**, with no action needed beyond the
notice: `libmpv-2.dll` is dynamically linked and installed as a loose file next
to the executable, so a user may substitute their own build.

Required of the distributor:

1. State that the application uses libmpv and FFmpeg under **LGPLv3**.
2. Include the LGPLv3 text (and GPLv3, which LGPLv3 incorporates by reference). Both are in this folder: `COPYING.LGPLv3` and `COPYING.GPLv3`.
3. Point to the upstream sources listed above.
4. **Do not** statically link libmpv, and do not strip the DLL from the bundle in
   favour of an embedded copy.

The recommended place to satisfy (1)–(3) in a Flutter app is `showLicensePage`.

## ANGLE (`libEGL.dll`, `libGLESv2.dll`, `d3dcompiler_47.dll`, `vk_swiftshader.dll`, `vulkan-1.dll`, `zlib.dll`)

- **License:** BSD 3-Clause (ANGLE / Chromium), plus zlib licence for `zlib.dll`.
- **Source:** <https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES>
  (release `v1.0.1`), built from <https://chromium.googlesource.com/angle/angle>
- Permissive; requires only that the copyright notice be preserved.
