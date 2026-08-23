# Third-Party Notices

MacCellular is an independently designed self-hosted phone product built in this
repository. It also contains or depends on earlier and third-party work whose
copyright and licenses remain unchanged.

## VoHive / DJOneHub foundation

Earlier USB, AT, eSIM and modem-management code derives from VoHive/DJOneHub.
The repository root `LICENSE` and this required notice must remain present:

```text
Required Notice: Copyright iniwex5 (https://github.com/iniwex5/vohive)
```

## MaVo host-side work

The macOS UAC probing and QDC507 audio-host integration use ideas and host-side
source adapted from [MaVo](https://github.com/moluncn/mavo), under the MIT
License. The retained license is [`licenses/MaVo-LICENSE`](licenses/MaVo-LICENSE).

MacCellular does not include or redistribute MaVo's module-side kernel modules or
ARM helper. Users who prepare a compatible module-side runtime obtain it from
its original source under that source's terms.

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
