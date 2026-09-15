// SPDX-FileCopyrightText: 2026 Maxim Dokukin (maxdokukin.com)
// SPDX-License-Identifier: GPL-3.0-only
// xewe-os-module-web-interface/xewe-os-module-web-interface.ino
//
// Validation firmware for the WebInterface module: the XeWeOS framework plus this module.
// It also declares the modules this one requires (Wifi); scripts/validate.sh copies them in
// from their sibling repos.
// Build it with scripts/validate.sh rather than opening this sketch directly.

#include <XeWeOS.h>

#include "src/Wifi/Wifi.h"
#include "src/WebInterface/WebInterface.h"


xewe::os::ModuleController os({
    .project_name    = "xewe-os-module-web-interface",
    .version         = "0.1.0",
    .build_timestamp = __DATE__ " " __TIME__,
    .url             = "https://github.com/xewe-labs/xewe-os-module-web-interface",
});

Wifi         wifi          (os);
WebInterface web_interface (os, wifi);


void setup() {
    os.begin();
}

void loop() {
    os.loop();
}
