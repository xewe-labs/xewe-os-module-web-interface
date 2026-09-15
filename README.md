# xewe-os-module-web-interface

HTTP page and command endpoint for other devices on the network. A module for [XeWe OS](https://github.com/xewe-labs/xewe-os), built on the
[XeWeOS framework](https://github.com/xewe-labs/xewe-library-os).

## Commands

**Prefix:** `$web_interface` · requires Wifi

HTTP server on port 80 that serves a small page and accepts CLI commands from other devices on
the network (`GET /cmd?c=<command>`).

| Command | Description | Sample Usage |
| :--- | :--- | :--- |
| **`status`** | Server uptime and memory usage. | `$web_interface status` |

## Requirements

| | |
|---|---|
| Modules | [xewe-os-module-wifi](https://github.com/xewe-labs/xewe-os-module-wifi) |
| Libraries | XeWeOS (>=0.1.0) and its dependencies (XeWeUtils, XeWeSerial, XeWeNvs, XeWeCli, ArduinoJson) |
| Boards | ESP32-C3, ESP32-C6, ESP32-S3 (arduino-esp32 3.x) |

Metadata and dependencies are declared in [`module.properties`](module.properties).

## Layout

| Path | |
|---|---|
| `src/WebInterface/` | the module |
| `xewe-os-module-web-interface.ino` | validation firmware: framework + required modules + this module |
| `scripts/validate.sh` | assembles and compiles the validation firmware |

## Validate

Clone the modules this one requires next to this repo, then:

```bash
scripts/validate.sh                         # compile for c3, c6 and s3
scripts/validate.sh -b c3                   # one board
scripts/validate.sh -b c3 -p /dev/ttyACM0   # compile, upload and run on a board
```

The script copies this module and its required modules into `build/xewe-os-module-web-interface/` and compiles it with
`arduino-cli`. Environment variables:

* `XEWE_MODULES_DIR` - where required module repos are cloned (default: the folder containing this repo)
* `XEWE_LIBRARIES_DIR` - folder with `xewe-library-*` clones to build against instead of installed libraries

## Use in firmware

Copy `src/WebInterface/` (and the required modules' folders) into the sketch's `src/`, then:

```cpp
#include "src/Wifi/Wifi.h"
#include "src/WebInterface/WebInterface.h"

Wifi wifi(os);
WebInterface web_interface(os, wifi);
```

Declare required modules before this one.

## License

GPL-3.0. See [LICENSE.txt](LICENSE.txt).
