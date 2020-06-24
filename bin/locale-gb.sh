#!/bin/bash

# bash: warning: setlocale: LC_ALL: cannot change locale (en_GB.UTF-8)

# Message shown when logging onto a box next set to GB locale

locale-gb(){
    echo "LC_ALL=en_GB.UTF-8" >> /etc/environment
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "LANG=en_GB.UTF-8" > /etc/locale.conf
    locale-gen en_GB.UTF-8
}
