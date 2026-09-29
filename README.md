# xewe-os-module-web-interface — send CLI commands to the board over HTTP

XeWe OS module · created 2026-09-15 (split out of xewe-os, where it was developed from 2026-01) · Solo: Max Dokukin · Status: Active (0.1.0)

## Overview

HTTP page and command endpoint for other devices on the network. A module for
[XeWe OS](https://github.com/xewe-labs/xewe-os), built on the
[XeWeOS framework](https://github.com/xewe-labs/xewe-library-os). It starts an HTTP server on
port 80 that serves a small dark-themed page with one input box, and accepts CLI commands from
any device on the local network at `GET /cmd?c=<command>`. Each command is echoed to the serial
console and run through the same command line as serial input, so every installed module can be
driven from a browser, a script or another microcontroller.

## Highlights

- Two routes: `GET /` (embedded HTML page stored in flash with `PROGMEM`) and `GET /cmd?c=<command>` → `200 OK` or `400 Empty Command`
- The page sends commands with `fetch('/cmd?c=' + encodeURIComponent(...))` and flashes "Command Sent" / "Error Sending" / "Connection Error"
- `status` reports server uptime and heap usage (used / total bytes)
- Requires the Wifi module and prints the page URL (`http://<local ip>`) once the server starts

## How it works

```
browser / curl → GET /cmd?c=$pins gpio_toggle 8 → WebServer (port 80) → xewe_cli.execute(command) → module callback
```

- **`WebInterface` class** (`src/WebInterface/`) — a `xewe::os::Module` with id `web_interface`; requires Wifi (`add_requirement(wifi)`), cannot be disabled; `loop()` calls `handleClient()`.
- **`get_server()`** — exposes the `WebServer` so other code can register more routes.

### Commands

**Prefix:** `$web_interface` · requires Wifi

| Command | Description | Sample Usage |
| :--- | :--- | :--- |
| **`status`** | Server uptime and memory usage. | `$web_interface status` |

### HTTP API

| Route | Method | Response |
|---|---|---|
| `/` | GET | the command page (`text/html`) |
| `/cmd?c=<command>` | GET | runs `<command>`; `200 OK`, or `400 Empty Command` without `c` |

```bash
curl "http://192.168.1.50/cmd?c=%24pins%20gpio_toggle%208"
```

There is no authentication: anyone on the same network can send any command, including
`$system` commands. Use it on trusted networks only.

### Requirements

| | |
|---|---|
| Modules | [xewe-os-module-wifi](https://github.com/xewe-labs/xewe-os-module-wifi) |
| Libraries | XeWeOS (>=0.1.0) and its dependencies (XeWeUtils, XeWeSerial, XeWeNvs, XeWeCli, ArduinoJson) |
| Boards | ESP32-C3, ESP32-C6, ESP32-S3 (arduino-esp32 3.x) |

Metadata and dependencies are declared in [`module.properties`](module.properties).

### Layout

| Path | |
|---|---|
| `src/WebInterface/` | the module (`WebInterface.h`, `WebInterface.cpp` with the embedded page) |
| `xewe-os-module-web-interface.ino` | validation firmware: framework + required modules + this module |
| `scripts/validate.sh` | assembles and compiles the validation firmware |
| `module.properties` | metadata read by xewe-os `setup.sh` and `validate.sh` |

## Results

| Metric | Value | Baseline / note |
|---|---|---|
| Source | 249 lines (`WebInterface.h` 34, `WebInterface.cpp` 215, page included) | `wc -l` |
| HTTP routes | 2 | `/`, `/cmd` |
| Validated boards | ESP32-C3, C6, S3 | `scripts/validate.sh` |

A module has no measured results; the table lists what it provides.

## Getting started

### Use in XeWe OS

Choose `web-interface` in xewe-os `setup.sh`; Wifi is added automatically.

### Validate

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

### Use in firmware

Copy `src/WebInterface/` (and the required modules' folders) into the sketch's `src/`, then:

```cpp
#include "src/Wifi/Wifi.h"
#include "src/WebInterface/WebInterface.h"

Wifi wifi(os);
WebInterface web_interface(os, wifi);
```

Declare required modules before this one.

## Documents

- [module.properties](module.properties)
- Firmware: [xewe-os](https://github.com/xewe-labs/xewe-os) · registry: [xewe-os-modules](https://github.com/xewe-labs/xewe-os-modules) · framework: [xewe-library-os](https://github.com/xewe-labs/xewe-library-os)
- License: GPL-3.0. See [LICENSE.txt](LICENSE.txt).
