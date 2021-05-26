#!/bin/zsh
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# File Name: checkInWatcherCreator.sh
#
# Description: Force Trigger a policy or jamf binary flag within moment of updating a computer inventory room value.
# Created by: mbrono
# Updated by: Matin Sasaluxanon
# Created on: 2020-06-23
# Last Updated: 2021-04-09
# Custom Version: 0.01.02
# Requirements:
#           - Jamf Pro
#           - macOS Clients running version 10.13 or later
#           - Custom configuration profile
#           - Custom script
#           - Custom smart group
# Reference:
#           - https://github.com/mhrono/jamf-checkin-watcher
#
# Version History:
#           2021-04-09 - 0.1.02
#           - added to select statement
#             - manage
#             - log
#             - stop-jamf
#             - any to run custom trigger
#           - added line to stop launcDaemon if upgrading/running
#           
#           2021-04-09 - 0.1.01
#           - Created script and setup in jamf pro to validate operational
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## Run this script on your endpoints to prepare them for instantaneous policy execution via configuration profile
## This script will create and load the checkinwatcher LaunchDaemon and script called by the LaunchDaemon to actually execute the check-in

## Set your org name here (no spaces)
orgName="contextlabs"

if [[ ! $orgName ]]; then echo "Org name not set, exiting!"; exit 1; fi

#### DO NOT EDIT BELOW THIS LINE ####

## Make the directory structure for your org if it doesn't already exist
mkdir -p "/Library/Application Support/$orgName"

## Write out the script
cat << EOF > "/Library/Application Support/$orgName/checkin.sh"
#!/bin/bash
shopt -s extglob

if [[ -e "/Library/Managed Preferences/com.$orgName.checkin.plist" ]]; then
	policyid=\$(defaults read "/Library/Managed Preferences/com.$orgName.checkin.plist" policyid)
	case "\$policyid" in
		+([[:digit:]]) )
			/usr/local/bin/jamf policy -id \$policyid
			;;
		stop-jamf)
			/usr/bin/killall jamf
			;;
		manage)
			/usr/local/bin/jamf manage
			;;
		log)
			/usr/local/bin/jamf log
			;;
		default)
			/usr/local/bin/jamf policy
			;;
		*)
			# added custom trigger option when anything is in the room field
			/usr/local/bin/jamf policy -event \$policyid
			;;
	esac

/usr/local/bin/jamf recon -room "none"

fi
EOF

## Make script executable
chmod +x "/Library/Application Support/$orgName/checkin.sh"

##stop launcDaemon if upgrading/running
launchctl unload -w /Library/LaunchDaemons/com.$orgName.checkinwatcher.plist

## Write out the LaunchDaemon
cat << EOF > "/Library/LaunchDaemons/com.$orgName.checkinwatcher.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.$orgName.checkinwatcher</string>
	<key>ProgramArguments</key>
	<array>
		<string>sh</string>
		<string>/Library/Application Support/$orgName/checkin.sh</string>
	</array>
	<key>WatchPaths</key>
	<array>
		<string>/Library/Managed Preferences/com.$orgName.checkin.plist</string>
	</array>
</dict>
</plist>
EOF

## Set permissions and load the LaunchDaemon
chown root:wheel /Library/LaunchDaemons/com.$orgName.checkinwatcher.plist
chmod 644 /Library/LaunchDaemons/com.$orgName.checkinwatcher.plist
launchctl load -w /Library/LaunchDaemons/com.$orgName.checkinwatcher.plist
