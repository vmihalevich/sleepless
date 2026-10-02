#!/bin/sh
# Grants passwordless root for exactly `pmset -a disablesleep 0|1` and installs a boot-time reset.
# Must run as root: the .pkg postinstall and the app's one-time admin prompt both call it.
set -eu

RULE=/etc/sudoers.d/sleepless
DAEMON=/Library/LaunchDaemons/dev.mihalevich.sleepless.reset.plist

tmp=$(mktemp /tmp/sleepless.XXXXXX)
trap 'rm -f "$tmp"' EXIT

cat > "$tmp" <<'RULE'
%admin ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
RULE
# A malformed file in sudoers.d breaks sudo for everyone, so it is validated before it lands.
/usr/sbin/visudo -cqf "$tmp"
mkdir -p /etc/sudoers.d
install -m 0440 -o root -g wheel "$tmp" "$RULE"

# If the Mac restarts with the flag still set (crash, forced shutdown), normal sleep comes back at boot.
cat > "$tmp" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>dev.mihalevich.sleepless.reset</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/pmset</string>
		<string>-a</string>
		<string>disablesleep</string>
		<string>0</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
PLIST
install -m 0644 -o root -g wheel "$tmp" "$DAEMON"
