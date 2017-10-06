#!/bin/bash

####################################################################
#                                                                  #
# ** IMPORTANT **                                                  #
#                                                                  #
# discover-devices uses the "hal" tools to detect input devices.   #
#                                                                  #
# These tools are obsolete, udev is the first alternative indicated #
#    by community.                                                 #
#                                                                  #
# Hal was installed using                                          #
#  add-apt-repository ppa:mjblenner/ppa-hal                        #
#  apt-get update && apt-get install hal                           #
#                                                                  #
####################################################################

set -x

export PATH=$PATH:$(pwd)

source find-devices.sh

echo "Multiseat C3SL"
MC3SL_SCRIPTS=$(pwd) #/usr/sbin/
MC3SL_DEVICES=$(pwd) #/etc/mc3sl/devices/

DISCOVER_DEVICES=$MC3SL_SCRIPTS/discover-devices
FIND_KEYBOARD='fKeyboard'

nWindow=0
declare -a pidWindows
declare -a idWindows
declare -a pidXorgs
declare -a displayXorgs
declare -a pidFindDevices
declare -a seatNames

execX () {
	displayXorgs[$nWindow]=$1

	# runs Xorg on a specific display and get pid to destroy the process later
	export DISPLAY=${displayXorgs[$nWindow]}

	Xorg ${displayXorgs[$nWindow]} &
	pidXorgs[$nWindow]=$! # get the pid to (maybe?) destroy the Xorg later

	sleep 1 # making sure that Xorg is up
}

createWindow () {
	# get screen resolution
	screenResolutionX=$(xdpyinfo -display ${displayXorgs[$nWindow]} | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/' | cut -d'x' -f1) #/ $(($nWindow+1)) ))
	screenResolutionY=x$(xdpyinfo -display ${displayXorgs[$nWindow]} | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/' | cut -d'x' -f2)
	screenResolution=$screenResolutionX$screenResolutionY

	window_name=w$(($nWindow+1))

	# create new window
	seat-parent-window $screenResolution+0+0 $window_name &

	# get the pid to destroy the window later
	pidWindows[$nWindow]=$!

	sleep 1 # making sure that window is up

	# get window id
	idWindows[$nWindow]=$(xwininfo -name $window_name | grep "Window id" | cut -d ' ' -f4)

	writeWindow wait_load $nWindow

	# increase number of windows
	nWindow=$(($nWindow+1))
}

writeWindow() {
	export DISPLAY=${displayXorgs[$2]}
	case $1 in
	ok) 
		write-message ${idWindows[$2]} "Monitor configurado, aguarde o restante ficar pronto" ;;
	wait_load) 
		write-message ${idWindows[$2]} "Aguarde" ;;
	press_key) 
		write-message ${idWindows[$2]} "Pressione a tecla F$(($2+1))" ;;
	press_mouse) 
		write-message ${idWindows[$2]} "Pressione o botão esquerdo do mouse" ;;
    esac
}

find_device () {
	for window in `seq 0 $(($nWindow-1))`; do
		$FIND_KEYBOARD $(($window+1)) ${seatNames[$window]} &
		pidFindDevices[$window]=$!

		writeWindow press_key $window
	done
}

systemctl stop lightdm
loginctl flush-devices

### TO-DO: o melhor jeito é garantir que o xorg-daemon.service rode antes

#Xorg :90 -seat __fake-seat-1__ &
Xorg :90 -seat __fake-seat-1__ -dpms -s 0 -nocursor &
pidFakeX=$! #nao criar janela, entao nao incrementar nWindow e vai dar errado...
sleep 1
### TO-DO end

FAKE_DISPLAY=:$(ps aux | grep Xorg | cut -d ":" -f4 | cut -d " " -f1)
export DISPLAY=$FAKE_DISPLAY

while read -r outputD ; do
	displayXorgs[$nWindow]=:$(($nWindow+10))

	Xephyr -output $outputD ${displayXorgs[$nWindow]} &
	
	pidXorgs[$nWindow]=$! 
	sleep 1
	export DISPLAY=${displayXorgs[$nWindow]}
	createWindow

	export DISPLAY=$FAKE_DISPLAY
	echo "loop $outputD"
done < <(xrandr | grep connect | cut -d " " -f1)

find_device

execX :$(($nWindow+10))
seatNames[$nWindow]=seat0

sleep 1

createWindow

find_device

for device in `seq 0 $(($nWindow-1))`; do
    wait ${pidFindDevices[$device]}
done

 kills all processes that will no longer be used

#read a

kill -9 $pidFakeX
for i in `seq 0 $(($nWindow-1))`; do
	if [[ -n "$(ps aux | grep ${pidXorgs[$i]})" ]]; then
		kill -9 ${pidXorgs[$i]}
	fi

	if [[ -n "$(ps aux | grep ${pidWindows[$i]})" ]]; then
		kill -9 ${pidWindows[$i]}
	fi

	if [[ -n "$(ps aux | grep ${pidFindDevices[$i]})" ]]; then
		kill -9 ${pidFindDevices[$i]}
	fi

	if [[ -n "$(ls | grep lock)" ]]; then
		rm lock*
	fi

	if [[ -n "$(ls | grep log)" ]]; then
		rm log*
	fi
done

sleep 1

systemctl start lightdm

exit 0
