#!/bin/sh
# Removes Sleepless completely and restores normal sleep. Run: sudo sh uninstall.sh
set -u

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as root: sudo sh $0" >&2
	exit 1
fi

pkill -x Sleepless 2>/dev/null
/usr/bin/pmset -a disablesleep 0
rm -f /etc/sudoers.d/sleepless
rm -f /Library/LaunchDaemons/dev.mihalevich.sleepless.reset.plist
rm -rf /Applications/Sleepless.app
pkgutil --forget dev.mihalevich.sleepless >/dev/null 2>&1
echo "Sleepless removed, normal sleep restored."
