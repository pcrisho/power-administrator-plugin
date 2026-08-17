# Configuration

## What is user-configurable?

| Setting | Configurable? | How |
|---|---|---|
| **Charge cap %** (80% vs 85%) | ❌ **No** on hardware exposing only `conservation_mode` | `conservation_mode` is a binary 0/1 flag; the ~80% value is fixed by the Lenovo firmware (embedded controller). Where no `charge_control_end_threshold` attribute exists, no tool (this plugin, TLP, or any other) can change it to 85%. Only on hardware exposing `charge_control_end_threshold` (ThinkPad, ASUS, Dell, Framework…) is the percentage selectable. |
| **Discharge / notification threshold** (35%) | ⚠️ Yes, but manually | The low-battery notification threshold lives in the `pcrisho.battery` service clone: edit `batteryThreshold` in `~/.config/omarchy/plugins/pcrisho.battery/Service.qml`. Changing the shipped Omarchy value (10%) this way is exactly why the plugin is a *clone* — an Omarchy update will not overwrite it. |
| **Conservation on every boot** | Yes | `systemctl disable battery-conservation.service` disables the boot-time re-application. The widget toggle keeps working (it just won't be re-enforced after a reboot). |
| **Icon refresh interval** | Yes | `refreshInterval` property in `Panel.qml` (default 30s). |

## Why can't the user just set 85%?

The charge limit is enforced by the laptop's embedded controller, not by
Linux. On conservation-mode hardware (e.g. the tested ThinkBook 14 G9 IRL)
the EC only understands "conservation mode on/off" and internally caps
charging at ~80%. Software can only flip that flag.

## Proposed future improvement

Expose the notification threshold as a real user setting instead of a QML
constant, e.g. a config file (`~/.config/omarchy/plugins/pcrisho.battery/
config.json`) or a value read from `shell.json`. The current hardcoded
property is functional but requires editing QML.

## Related setup (test machine)

- `/etc/systemd/system/battery-conservation.service` — oneshot that writes
  `1` to `conservation_mode` at boot (enabled).
- Battery service clone `pcrisho.battery` — `omarchy.battery` disabled;
  clone `batteryThreshold: 35`.