# Third-Party Notices

NasAnySim is a derivative work based on **MacCellular 1.0.0-rc.4**
(https://github.com/yuexiazhuojiu-byte/MacCellular), with substantial
modifications for deployment as a self-hosted cellular gateway on NAS/ARM
Linux. It also contains or depends on earlier and third-party work whose
copyright and licenses remain unchanged.

## Upstream: MacCellular (VoHive/DJOneHub lineage)

The mobile-web remote gateway, communication architecture, media integration,
storage and deployment work derives from MacCellular (in turn derived from
VoHive/DJOneHub). The upstream `LICENSE` and `NOTICE` are preserved in this
repository **and inside the published container image**.

The repository root `LICENSE` and this required notice must remain present:

```text
Required Notice: Copyright iniwex5 (https://github.com/iniwex5/vohive)
```

## MaVo host-side work & module-side runtime

The macOS UAC probing and QDC507 audio-host integration use ideas and host-side
source adapted from [MaVo](https://github.com/moluncn/mavo), under the MIT
License. The retained license is [`licenses/MaVo-LICENSE`](licenses/MaVo-LICENSE).

The published container image **includes the module-side voice runtime**
(`/opt/nasany/module-voice/`: `qdc507_aprv3.ko`, `qdc507_voice.ko`,
`mavo-pcm-bridge.armv7`) so a DJI/BAIWANG QDC507 module works out of the box.
These files are pushed to the module over ADB at deployment time. They derive
from work distributed with MaVo / the module vendor and are used under their
original terms; see `licenses/MaVo-LICENSE`.

## Pion WebRTC

The remote media path uses Pion WebRTC and related Pion modules under the MIT
License. Their license texts are retained under `licenses/Pion*-LICENSE`.

## libusb

The macOS release uses libusb, distributed under LGPL-2.1-or-later. Packaging
scripts copy the libusb license into the release payload.

## Vendored Go source

The repository includes selected dependencies under `third_party/`. Their
original license files remain in the corresponding directories, including:

- `third_party/euicc-go/LICENSE`
- `third_party/euicc-go/bertlv/LICENSE`
- `third_party/uicc-go/LICENSE`
- `third_party/quectel-qmi-go/LICENSE`
- `third_party/strftime/LICENSE`
- `third_party/pkg-errors/LICENSE`
- `third_party/x-sys/LICENSE`
- `third_party/x-text/LICENSE`
- `third_party/multierr/LICENSE.txt`

Other Go modules retain their respective upstream copyright and license terms.
This notice is a navigation aid and does not replace any full license text.
