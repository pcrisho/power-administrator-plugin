# Known issues & risks

## 1. Omarchy updates can break the plugin

The plugin depends on the Omarchy shell's internal API: `Panel`,
`BarIconButton`, `KeyboardPanel`, `Style`, `Color`, `qs.Ui`, and the IPC
interface. User plugins live in `~/.config/omarchy/plugins/` and **survive**
Omarchy updates, but:

- The shell's component API can change between versions → the plugin may fail
  to load (check `journalctl --user -u omarchy-shell` or the plugin list).
- **Mitigation**: pin a working Omarchy version before updating, and test
  `omarchy plugin rescan` after every update.

## 2. The battery clone is frozen at the original's snapshot

`pcrisho.battery` is a copy of Omarchy's `Service.qml` with
`batteryThreshold: 35`. When Omarchy improves its battery service, the clone
**keeps working but does not receive improvements**. If a future Omarchy
version changes the service's internal structure (e.g. imports,
`Quickshell.Services.UPower`), the clone may break.

- **Mitigation**: re-sync the clone from the new original after updates,
  re-applying the threshold change.

## 3. Live plugin reload is flaky

Observed during development: `omarchy plugin rescan` / reload occasionally
fails to load the cloned service with `service plugin load failed for
pcrisho.battery ... No such file or directory`. The plugin loads correctly
after a shell restart.

- **Workaround**: restart the shell (`omarchy restart shell`).
- This looks like a shell reload quirk, not a plugin bug.

## 4. Kernel / driver regressions

The plugin reads and writes
`/sys/bus/platform/devices/VPC2004:00/conservation_mode`, provided by
`ideapad_laptop`. If a kernel update breaks the driver (or the EC stops
exposing the attribute), the widget silently shows `off` and toggles have no
effect.

- **Check**: `cat /sys/bus/platform/devices/VPC2004:00/conservation_mode`
  and `lsmod | grep ideapad_laptop`.

## 5. Polkit dependency

The toggle runs `pkexec sh -c ...` and depends on the Omarchy polkit agent
(`omarchy.polkit`). If the agent is down, no prompt appears and nothing
changes — no error is shown.

- **Check**: `omarchy plugin list` → `omarchy.polkit` enabled.

## 6. The displayed "80%" is an assumption

The panel shows "Limit to 80%". Some Lenovo models (e.g. certain Legion
models) cap at **60%**. On the tested model (ThinkBook 14 G9 IRL) it is 80%,
but if the plugin is used on another model the text may be wrong.

- **Mitigation**: read the real cap from the firmware docs of the target
  model, or show the UPower state ("Holding") instead of a hardcoded number.

## 7. Refresh delay

The widget re-reads state every 30s. Changes made outside the widget (e.g.
`echo 0 > .../conservation_mode` in a terminal) take up to 30s to reflect.

## 8. Single battery assumption

The plugin reads `BAT0` (UPower device) for the battery % shown in the panel.
Dual-battery systems would show only the first battery.

## 9. Security note (by design)

`pkexec sh -c "echo ... > /sys/..."` executes as root after the user
authenticates. This is the standard user-script model, but note that anyone
who can edit `Panel.qml` in `~/.config/omarchy/plugins/` (the user's own
directory) could change the command that runs as root.

## 10. Icon theme gap: the Vantablack theme references a missing Yaru-gray icon theme

Observed on the test machine (Omarchy 4.0.0, theme `vantablack`):

- The theme's `icons.theme` template sets the GNOME icon theme to
  `Yaru-gray`, but **no `Yaru-gray` icon theme exists** on the system: the
  installed `yaru-icon-theme` package ships Yaru, Yaru-dark, Yaru-blue, …
  but not the gray variant.
- Consequence: every themed-icon lookup fails, and notifications requesting
  an icon by name (e.g. `omarchy-battery-low`'s `-i battery-caution`)
  render Qt's **broken-image placeholder** (black/fuchsia checkerboard)
  instead of the icon. Logged as:
  `WARN: Could not load icon "battery-caution" at size QSize(40, 40) from request`.
- This is an **Omarchy theme packaging gap**, not a plugin bug — with any
  resolvable Yaru variant the icon loads fine.

**Diagnosis**

```bash
gsettings get org.gnome.desktop.interface icon-theme   # e.g. 'Yaru-gray'
ls /usr/share/icons | grep -i yaru-gray                # empty → theme missing
```

**Workaround (verified)**

1. Copy the theme to your user config (user copies take priority):
   ```bash
   cp -a "$(omarchy theme dir vantablack)" ~/.config/omarchy/themes/vantablack
   echo "Yaru-dark" > ~/.config/omarchy/themes/vantablack/icons.theme
   omarchy theme refresh
   ```
   (`Yaru-dark` — or any installed variant — replaces the missing one.)
2. Confirm: `gsettings get org.gnome.desktop.interface icon-theme` → a value
   that exists in `/usr/share/icons/`, and re-send the notification.

**Upstream**: worth reporting to Omarchy (theme template vs. shipped icon
package mismatch).