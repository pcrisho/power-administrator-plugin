# Validation

Reference test environment: Omarchy 4.0.0, Lenovo ThinkBook 14 G9 IRL,
kernel `ideapad_laptop` present. Your results may differ on other hardware —
check [Compatibility](COMPATIBILITY.md).

## Charge limit toggle

1. `cat /sys/bus/platform/devices/VPC2004:00/conservation_mode` → `1`
   (limit active after boot, re-applied by `battery-conservation.service`).
2. Left click the bar icon → polkit prompt appears → authenticate.
3. Re-read the attribute → value flipped (0 ↔ 1); icon updated.
4. Repeat in both directions using the panel buttons (`Limit to 80%` /
   `Full charge`).
5. IPC checks:

```bash
omarchy shell pcrisho.power-admin state      # → "on" | "off"
omarchy shell pcrisho.power-admin toggle
omarchy shell pcrisho.power-admin setLimit on
```

6. Expected battery behaviour once the cap is active and AC is connected:
   `upower -i ...battery_BAT0` shows the battery hovering at 80% with
   status `Holding` (charge paused), never reaching `Full`.

## Charge cap is firmware-fixed

Verified that no percentage interface exists on this model:

```bash
ls /sys/bus/platform/devices/VPC2004:00/   # only conservation_mode
find /sys -name "charge_control*"           # nothing
```

→ 80% is not user-configurable on this hardware (see CONFIGURATION).

## Persistence service

- `systemctl status battery-conservation.service` → active (oneshot), ran at
  boot.
- After `echo 0 > .../conservation_mode` and a reboot, the value is `1`
  again.

## Low-battery notification (35%)

- `pcrisho.battery` service clone active (shell.json: `omarchy.battery`
  disabled, clone enabled).
- `batteryThreshold: 35` present in the clone's `Service.qml`.
- The notification fires **only while discharging** below the threshold,
  once per discharge cycle (the "already notified" flag resets when charging
  or above the threshold). Expected output (from
  `/usr/share/omarchy/bin/omarchy-battery-low`): critical notification
  "Time to recharge!" / "Battery is down to N%".
- **Known pitfall (observed)**: after creating/editing the clone, live
  plugin reloads can fail with `service plugin load failed for
  pcrisho.battery ... No such file or directory`, leaving the service
  unloaded and the notification silent. Fix: restart the shell
  (`omarchy restart shell`) — a clean start loads the clone without errors.
- **To validate**: with the shell freshly restarted and the battery
  discharging below 35%, the notification appears within ~30s. Confirm via
  the shell log (no load failure) and/or
  `~/.local/state/omarchy/notifications/history/`.
- Status: **validated end-to-end** — notification received at 35% on a real
  discharge (Aug 2026).
- **Icon note**: the notification requests the themed icon `battery-caution`
  (via `-i`). If the active icon theme cannot resolve it, the icon slot
  renders Qt's broken-image placeholder (black/fuchsia checkerboard) instead
  of the icon. See [KNOWN-ISSUES #10](KNOWN-ISSUES.md#10-icon-theme-gap-the-vantablack-theme-references-a-missing-yaru-gray-icon-theme).

## Plugin load

- `omarchy plugin list` shows `pcrisho.power-admin` and `pcrisho.battery`
  enabled.
- After a shell restart both load cleanly. Live `plugin rescan` has shown
  flaky service-clone loading (see KNOWN-ISSUES #3) — restart the shell to
  recover.
- IPC works with a 15s timeout (shell can answer slowly):
  `OMARCHY_SHELL_IPC_TIMEOUT=15s`.

## Reproduce quickly

```bash
# state check
cat /sys/bus/platform/devices/VPC2004:00/conservation_mode

# simulate external change → widget should catch up within 30s
sudo sh -c 'echo 0 > /sys/bus/platform/devices/VPC2004:00/conservation_mode'
```