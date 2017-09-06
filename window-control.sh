#!/bin/bash

set -x

export PATH=$PATH:$(pwd)

execX () {
	displayXorgs[$nWindow]=$1

	# runs Xorg on a specific display and get pid to destroy the process later
	export DISPLAY=${displayXorgs[$nWindow]}

	Xorg ${displayXorgs[$nWindow]} &
	pidXorgs[$nWindow]=$! # get the pid to (maybe?) destroy the Xorg later

	sleep 1 # making sure that Xorg is up
}

createWindow () {
	echo "############## DEBUG ##############"

	# increase number of windows
	nWindow=$(($nWindow+1))

	# get screen resolution
	screenResolutionX=$(( $(xdpyinfo -display ${displayXorgs[$(($nWindow-1))]} | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/' | cut -d'x' -f1) / $nWindow ))
	screenResolutionY=x$(xdpyinfo -display :10 | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/' | cut -d'x' -f2)
	screenResolution=$screenResolutionX$screenResolutionY

	# create new window
	seat-parent-window $screenResolution+0+0 w$nWindow &

	echo "Create window "w$nWindow
	echo "screen resolution = " $screenResolution+0+0

	# get the pid to destroy the window later
	pidWindows[$(($nWindow-1))]=$!
	echo "pid window: " ${pidWindows[$(($nWindow-1))]}

	sleep 1 # making sure that window is up

	# get window id
	idWindows[$(($nWindow-1))]=$(xwininfo -name w$nWindow | grep "Window id" | cut -d ' ' -f4)
	echo "id window: " ${idWindows[$(($nWindow-1))]}

	echo "############## DEBUG ##############"
}

writeWindow() {
	export DISPLAY=${displayXorgs[$2]}
	case $1 in
	wait_load) 
		write-message ${idWindows[$2]} "Wait, loading" ;;
	press_key) 
		write-message ${idWindows[$2]} "Press F$(($2+1)) key" ;;
	press_mouse) 
		write-message ${idWindows[$2]} "Press the mouse left button" ;;
    esac
}