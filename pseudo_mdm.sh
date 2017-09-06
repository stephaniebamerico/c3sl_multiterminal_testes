#!/bin/bash

####################################################################
#                                                                  #
# ** IMPORTANT **                                                  #
#                                                                  #
# discover-devices uses the "hal" tools to detect input devices.   #
#                                                                  #
# This tools are obsolete, udev is the first alternative indicated #
#    by community.                                                 #
#                                                                  #
# Hal was installed using                                          #
#  add-apt-repository ppa:mjblenner/ppa-hal                        #
#  apt-get update && apt-get install hal                           #
#                                                                  #
####################################################################

SEAT_NAME=seat-S2
echo -n "Seat name: "
echo "$SEAT_NAME"

export PATH=$PATH:~admin/Documentos/teste

export DISPLAY=:90

# ensure lightdm is not running
systemctl stop lightdm


CARD=/sys/bus/pci/devices/0000:$(lspci | grep 'Silicon.Motion' | cut -d ' ' -f1)
SYS_CARD=/sys$(udevadm info $CARD | grep 'P:' | cut -d ' ' -f2-)


loginctl attach $SEAT_NAME $SYS_CARD

echo -n "Card: "
echo "$SYS_CARD"

# run Xephyr in DISPLAY:1
Xephyr :1 &

sleep 2

# set display geometry
seat-parent-window 500x500+0+0 a1 &

sleep 2

# no idea
WINDOW_ID=$(xwininfo -name a1 | grep "Window id" | cut -d ' ' -f4)

write-message $WINDOW_ID "Press any key"

# get connected devices
KEYBOARDS=$(discover-devices kevdev | cut -f2)

# get keyboard that has an input
PRESSED=$(read-devices 1 $KEYBOARDS | grep '^detect' | cut -d '|' -f2)
SYS_DEV=/sys$(udevadm info $PRESSED | grep 'P:' | cut -d ' ' -f2- | sed -r 's/event.*$//g')

loginctl attach $SEAT_NAME $SYS_DEV

# show the keyboard
echo -n "Keyboard: "
echo "$SYS_DEV"


