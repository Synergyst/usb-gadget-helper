#!/bin/bash

g++ audio-gadget-helper.cpp -o ./audio-gadget-helper
if [[ $? -eq 0 ]]; then
  for m in {1..27} ; do
    ./audio-gadget-helper $m
    if [[ $? -ne 0 ]]; then
      echo 'One of the tests failed, exiting..'
      exit 1
    fi
  done
  echo 'All tests passed, installing..'
  cp audio-gadget-helper /usr/local/bin/
fi

./usb-gadgets.sh stop
#mv /var/lib/alsa/asound.state /var/lib/alsa/asound.state.bak ; alsactl store
./usb-gadgets.sh start
