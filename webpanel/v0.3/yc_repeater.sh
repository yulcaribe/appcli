#!/bin/sh
# YulCaribe H298A repeater runtime controller v0.3
# RAM-only experiments. Never saves ZTE configuration or touches MTD.
set -u
DIR=/tmp/yc_repeater
mkdir -p "$DIR" || exit 2
chmod 700 "$DIR" 2>/dev/null
umask 077
MODE_CMD='cspd..multiapd_mgr'

say() { echo "$*"; }
run_iw() { iwpriv "$1" set "$2"; }
case "${1:-}" in
 status)
  echo '=== ZTE WORK MODE ==='
  sendcmd "$MODE_CMD" show 2>&1 || echo 'STATUS_TIMEOUT_OR_ERROR'
  echo '=== STA NETDEV ==='
  for dev in apcli0 apcli1 apcli5g0 apclii0 apclii1; do
   if [ -d "/sys/class/net/$dev" ]; then ifconfig "$dev" 2>&1; fi
  done
  echo '=== LAN ==='
  ifconfig br0 2>&1 | head -n 4
  brctl show 2>&1
  ;;
 scan2g|scan5g)
  if [ "$1" = scan2g ]; then IF=wlan0; B=2g; else IF=wlan5g0; B=5g; fi
  say "Band=$B Interface=$IF"
  say 'Trigger: iwpriv set SiteSurvey=1'
  if ! run_iw "$IF" 'SiteSurvey=1' > "$DIR/scan_${B}_trigger.log" 2>&1; then
    say 'ERROR: SCAN_TRIGGER_FAILED'
    cat "$DIR/scan_${B}_trigger.log"
    exit 10
  fi
  sleep 4
  say '=== SURVEY ==='
  if ! iwpriv "$IF" get_site_survey > "$DIR/scan_${B}.txt" 2> "$DIR/scan_${B}_err.log"; then
    say 'ERROR: GET_SITE_SURVEY_FAILED'
    cat "$DIR/scan_${B}_err.log"
    exit 11
  fi
  cat "$DIR/scan_${B}.txt"
  ;;
 publish2g|publish5g)
  if [ "$1" = publish2g ]; then IF=wlan0; B=2g; else IF=wlan5g0; B=5g; fi
  if [ ! -f "$DIR/ap_${B}_ssid" ] || [ ! -f "$DIR/ap_${B}_psk" ]; then
    say 'ERROR: PUBLISH_PROFILE_MISSING'; exit 12
  fi
  IFS= read -r SSID < "$DIR/ap_${B}_ssid"
  IFS= read -r KEY < "$DIR/ap_${B}_psk"
  rm -f "$DIR/ap_${B}_ssid" "$DIR/ap_${B}_psk"
  say "Applying runtime AP profile on $IF (not saved to flash)"
  # Ralink/MediaTek AP ioctls: values are passed as one argument, no eval.
  if ! run_iw "$IF" 'AuthMode=WPA2PSK'; then say 'ERROR: AuthMode'; exit 20; fi
  if ! run_iw "$IF" 'EncrypType=AES'; then say 'ERROR: EncrypType'; exit 21; fi
  if ! run_iw "$IF" "SSID=$SSID"; then say 'ERROR: SSID'; exit 22; fi
  if ! run_iw "$IF" "WPAPSK=$KEY"; then say 'ERROR: WPAPSK'; exit 23; fi
  say "OK: AP $B runtime change submitted"
  ;;
 connect2g|connect5g)
  if [ "$1" = connect2g ]; then IF=wlan0; B=2g; STA=apcli0; else IF=wlan5g0; B=5g; STA=apcli5g0; fi
  if [ ! -f "$DIR/sta_ssid" ] || [ ! -f "$DIR/sta_psk" ]; then
    say 'ERROR: STA_PROFILE_MISSING'; exit 30
  fi
  IFS= read -r SSID < "$DIR/sta_ssid"
  IFS= read -r KEY < "$DIR/sta_psk"
  rm -f "$DIR/sta_ssid" "$DIR/sta_psk"
  say "STA band=$B, interface=$IF, preferred netdev=$STA"
  say 'NOTE: experimental ApCli ioctls; not every H298A driver build supports them.'
  # Test the driver capability first. Unsupported drivers return an ioctl error.
  if ! run_iw "$IF" 'ApCliEnable=0'; then
    say 'ERROR: APCLI_UNSUPPORTED_BY_DRIVER (first ioctl rejected)'
    exit 31
  fi
  if ! run_iw "$IF" 'ApCliAuthMode=WPA2PSK'; then say 'ERROR: APCLI_AUTH'; exit 32; fi
  if ! run_iw "$IF" 'ApCliEncrypType=AES'; then say 'ERROR: APCLI_CIPHER'; exit 33; fi
  if ! run_iw "$IF" "ApCliSsid=$SSID"; then say 'ERROR: APCLI_SSID'; exit 34; fi
  if ! run_iw "$IF" "ApCliWPAPSK=$KEY"; then say 'ERROR: APCLI_PASSWORD'; exit 35; fi
  if ! run_iw "$IF" 'ApCliEnable=1'; then say 'ERROR: APCLI_ENABLE'; exit 36; fi
  sleep 3
  if [ -d "/sys/class/net/$STA" ]; then
    say "STA_NETDEV_PRESENT $STA"
    iwconfig "$STA" 2>&1 | head -n 8
    # The ioctl returning success only means the request was accepted.
    # It is not proof that a WPA handshake completed.
    if iwconfig "$STA" 2>&1 | grep -q 'Access Point: Not-Associated'; then
      say 'ERROR: STA_NOT_ASSOCIATED'; exit 38
    fi
    say 'STA setup submitted; association and IP/Internet still require verification.'
  else
    say 'ERROR: STA_NETDEV_NOT_PRESENT: station interface did not appear'
    exit 37
  fi
  say 'LAN bridging/routing is not configured by this experimental controller.'
  ;;
 apon2g|apoff2g|apon5g|apoff5g)
  if [ "$1" = apon2g ] || [ "$1" = apoff2g ]; then IF=wlan0; else IF=wlan5g0; fi
  case "$1" in
   apon*) ifconfig "$IF" up || exit 42; say "OK: $IF enabled at runtime" ;;
   apoff*)
     # A safety restore avoids locking out Wi-Fi-only admins.
     ( sleep 90; ifconfig "$IF" up ) </dev/null >/dev/null 2>&1 &
     ifconfig "$IF" down || exit 43
     say "OK: $IF disabled temporarily, automatically re-enabled in 90 seconds"
     ;;
  esac
  ;;
 mode7)
  rm -f "$DIR/mode_confirmed"
  echo "$$" > "$DIR/mode_generation"
  MY_GENERATION="$$"
  # Detached rollback is best effort and can fail if processes restart.
  ( sleep 180
    LATEST="$(cat "$DIR/mode_generation" 2>/dev/null)"
    if [ "$LATEST" = "$MY_GENERATION" ] && [ ! -f "$DIR/mode_confirmed" ]; then
      echo '180s expired; reverting to mode 1' >> "$DIR/mode.log"
      sendcmd "$MODE_CMD" setmode 1 >> "$DIR/mode.log" 2>&1
    fi
  ) </dev/null >/dev/null 2>&1 &
  echo 'MODE7: rollback scheduled in 180s unless confirmed'
  ( sendcmd "$MODE_CMD" setmode 7 > "$DIR/mode.log" 2>&1 ) </dev/null >/dev/null 2>&1 &
  echo 'MODE7: requested asynchronously; check Status after reconnect'
  ;;
 mode1)
  : > "$DIR/mode_confirmed"
  echo "reverted-$$" > "$DIR/mode_generation"
  ( sendcmd "$MODE_CMD" setmode 1 > "$DIR/mode.log" 2>&1 ) </dev/null >/dev/null 2>&1 &
  say 'MODE1: revert requested asynchronously'
  ;;
 confirm)
  : > "$DIR/mode_confirmed"
  say 'MODE: automatic rollback disarmed for this request'
  ;;
 log)
  if [ -f "$DIR/mode.log" ]; then cat "$DIR/mode.log"; fi
  ;;
 *)
  say 'ERROR: invalid action'; exit 64
  ;;
esac
