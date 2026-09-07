#!/bin/sh
# Watch the Echo Show for network drops: ICMP every 1s, VACA port every 10s.
IP=192.168.8.32
PORT=10800
DUR=${1:-600}
OUT=/config/echo_net_watch.log
: > "$OUT"
echo "watch start $(date '+%F %T %Z')  target=$IP  duration=${DUR}s" >> "$OUT"

i=0; lost=0; sent=0; portfail=0; portchecks=0; streak=0; maxstreak=0
end=$(( $(date +%s) + DUR ))
while [ "$(date +%s)" -lt "$end" ]; do
    sent=$((sent+1))
    if ping -c 1 -W 1 "$IP" >/dev/null 2>&1; then
        if [ "$streak" -gt 0 ]; then
            echo "$(date '+%F %T')  RECOVERED after ${streak}s of loss" >> "$OUT"
            [ "$streak" -gt "$maxstreak" ] && maxstreak=$streak
            streak=0
        fi
    else
        lost=$((lost+1)); streak=$((streak+1))
        [ "$streak" -eq 1 ] && echo "$(date '+%F %T')  ICMP LOSS begins" >> "$OUT"
    fi
    i=$((i+1))
    if [ $((i % 10)) -eq 0 ]; then
        portchecks=$((portchecks+1))
        if ! nc -z -w 2 "$IP" "$PORT" >/dev/null 2>&1; then
            portfail=$((portfail+1))
            echo "$(date '+%F %T')  PORT $PORT unreachable" >> "$OUT"
        fi
    fi
    sleep 1
done
[ "$streak" -gt "$maxstreak" ] && maxstreak=$streak
{
  echo "watch end   $(date '+%F %T %Z')"
  echo "icmp: sent=$sent lost=$lost  ($(( lost * 100 / sent ))% loss)  longest_gap=${maxstreak}s"
  echo "port $PORT: checks=$portchecks failures=$portfail"
} >> "$OUT"
