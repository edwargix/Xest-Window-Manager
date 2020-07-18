#!/bin/sh
#
# This code is released in public domain by Han Boetes <han@mijncomputer.nl>
#
# This script tries to exec a terminal emulator by trying some known terminal
# emulators.
for terminal in $TERMINAL x-terminal-emulator urxvt rxvt terminator Eterm aterm xterm gnome-terminal roxterm xfce4-terminal; do
    if which $terminal > /dev/null 2>&1; then
        exec $terminal "$@"
    fi
done
