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

SEAT_NAME=seat0

export PATH=$PATH:~admin/teste

export DISPLAY=:90

# ensure lightdm is not running
systemctl stop lightdm


# set display geometry
seat-parent-window 300x300+0+0 a1 &
ida1=$!

sleep 2

WINDOW_ID=$(xwininfo -name a1 | grep "Window id" | cut -d ' ' -f4)

write-message $WINDOW_ID "Press any key"

read a

kill $ida1

