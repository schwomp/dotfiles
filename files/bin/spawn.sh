#!/usr/bin/env bash
set -euo pipefail

#
# spawn
#
# Desc: switches focus to an application if it is running
# if not it starts the application
#
# Requirements
# Swaymsg
# jq
# kitty terminal emulator (can easily be changed to work
#       another terminal as long as it can assign the title
#
# Arguments:
# 1: name of application or session
#

function get_command () {
	# Function checks for a .desktop file that matches the app name and sets the
	# command to open the app to the 1st Exec statement in the .desktop file
	# if Terminal=true in the .desktop file it start the terminal with the app
	# name and if no .desktop file exists it simply attempts to start the app
	DESKTOP_FILE=$(ls -d $HOME/.local/share/applications/* /usr/share/applications/* \
		| grep -i "$1" \
		| awk 'NR==1{print $1}' )
	if [ -z $DESKTOP_FILE ]
	then
		COMM=$1
	else
		COMM=$(grep '^Exec' $DESKTOP_FILE | head -1  \
			| sed 's/^Exec=//' | sed 's/%.//' | sed 's/^"//g' | sed 's/" *$//g')
		if [ -z $DESKTOP_FILE ] || grep "Terminal=true" $DESKTOP_FILE
		then
			COMM="$TERMINAL -e $1"
		fi
	fi
	echo $COMM
}

function app_running () {
	# Compares the requested app to running apps list if it finds it it returns
	# only the name of the keys where it is found (i.e. app_id, class, or title)
	RUNNING_APP_TYPES=$(swaymsg -t get_tree | jq -r --arg TEST_APP "$1" 'recurse(.nodes[]?)
		| recurse(.floating_nodes[]?)
		| select(.type=="floating_con" or .type=="con")
		| {app_id: .app_id, class: .window_properties.class, title: .name}
		| with_entries(select(.value!=null))
		| with_entries(select(.value|test($TEST_APP))) | keys')

	# Gets just the first key name in the list.  The list is sorted by the best
	# match (app_id, class, title) so that the right window is chosen
	echo $(echo $RUNNING_APP_TYPES | awk -F'"' '$0=$2' | awk 'NR==1{print $1}')
}


[ -z "$1" ] && exit
APP_NAME=$1
EXECUTABLE=${2:-$APP_NAME}

DROPDOWN_APPS="bc\nzsh"

APP_TYPE=$(app_running $APP_NAME)
if [ ! -z $APP_TYPE ]
then
    swaymsg "[$APP_TYPE=\"$APP_NAME\"] focus"
else
    swaymsg exec -- $(get_command $EXECUTABLE)
    until [ ! -z $APP_TYPE ]
    do
        sleep 1
        APP_TYPE=$(app_running $APP_NAME)
        echo $APP_TYPE
    done
    swaymsg "[$APP_TYPE=\"$APP_NAME\"] focus"
fi
