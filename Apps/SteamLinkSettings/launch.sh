#!/bin/sh
# Steam Link Settings Configurator Launcher
APP_DIR="/mnt/SDCARD/Apps/SteamLink"
if [ -x "$APP_DIR/configure.sh" ]; then
    exec "$APP_DIR/configure.sh"
else
    sh "$APP_DIR/configure.sh"
fi

