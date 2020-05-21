#!/usr/bin/env sh

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch bar1 and bar2

#!/usr/bin/env bash

killall -q polybar

for m in $(polybar --list-monitors | cut -d":" -f1); do
    MONITOR=$m polybar --reload -c ~/.config/polybar/config.ini main &
done

echo "Bars launched..."
