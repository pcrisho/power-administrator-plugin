# Power Administrator — Omarchy plugin

Bar widget to toggle the **Lenovo battery conservation mode** (80% charge cap)
on `ThinkBook`/`IdeaPad` laptops from the Omarchy bar.

> **Tested on**: Omarchy 4.0.0, Lenovo ThinkBook 14 G9 IRL (kernel driver
> `ideapad_laptop`). See [Compatibility](docs/COMPATIBILITY.md) for other
> laptops.

## What it does

- Shows the current state in the bar: `󰂅` = limit active (stops at ~80%),
  `󰁹` = full charge allowed.
- **Left click** on the icon: toggle the limit (a polkit prompt asks for your
  password/fingerprint — the change needs root).
- **Right click**: open the panel with status, battery %, and explicit
  `Limit to 80%` / `Full charge` buttons.
- Re-reads the state every 30s, so it stays honest even if the value changes
  behind its back (e.g. `echo 1 > .../conservation_mode` from a terminal).

## Prerequisites

- [Omarchy](https://omarchy.org) (Hyprland/Quickshell shell)
- A Lenovo laptop exposing
  `/sys/bus/platform/devices/VPC2004:00/conservation_mode` (verify:
  `ls /sys/bus/platform/devices/VPC2004:00/conservation_mode`). Not sure if
  your model is supported? Read [Compatibility](docs/COMPATIBILITY.md).
- `pkexec` and a polkit agent (Omarchy ships `omarchy.polkit`, enabled by
  default)
- `git` and `jq` for the installer script

## Install

```bash
git clone https://github.com/pcrisho/power-administrator-plugin.git
cd power-administrator-plugin
./install.sh
```

What `install.sh` does:

1. Copies the plugin to `~/.config/omarchy/plugins/pcrisho.power-admin/`.
2. Asks the running shell to rescan its plugin registry.
3. Enables the widget in the bar's right section.

If the shell is slow to answer IPC calls (seen on some machines), the script
uses a 15s IPC timeout automatically; override with
`OMARCHY_SHELL_IPC_TIMEOUT=30s ./install.sh`.

### Optional: re-apply the limit on every boot

The widget only changes the setting for the current session. To keep the
battery protected after a reboot, install this systemd service (as root):

```bash
sudo tee /etc/systemd/system/battery-conservation.service > /dev/null <<'EOF'
[Unit]
Description=Enable Lenovo battery conservation mode (80% charge cap)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 1 > /sys/bus/platform/devices/VPC2004:00/conservation_mode'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now battery-conservation.service
```

With this service enabled, toggling the limit off from the widget only lasts
until the next reboot — by design, so the battery stays protected by default.

## Verify

```bash
omarchy shell pcrisho.power-admin state   # → "on" | "off"
cat /sys/bus/platform/devices/VPC2004:00/conservation_mode   # 1 = limit active
```

Click the bar icon; a polkit prompt should appear and the value should flip.

## Usage

| Action | Effect |
|---|---|
| Left click icon | Toggle charge limit (prompts via polkit) |
| Right click icon | Open panel |
| Panel buttons | Explicit `Limit to 80%` / `Full charge` |

## IPC

```bash
omarchy shell pcrisho.power-admin state      # on|off
omarchy shell pcrisho.power-admin toggle
omarchy shell pcrisho.power-admin setLimit on
```

## Configuration

- The **charge cap percentage** is *not* user-configurable on hardware that
  only exposes `conservation_mode` — the ~80% value is fixed by the Lenovo
  firmware. On laptops exposing `charge_control_end_threshold`
  (ThinkPad/ASUS/Dell/Framework) a custom percentage is possible.
- The **low-battery notification threshold** is configurable.

See [Configuration](docs/CONFIGURATION.md) for details.

## Troubleshooting

- **No polkit prompt on click**: check the Omarchy polkit agent is enabled
  (`omarchy plugin list` → `omarchy.polkit`).
- **Widget shows off and toggles do nothing**: the sysfs attribute may be
  missing (unsupported model or driver issue). Check
  `ls /sys/bus/platform/devices/VPC2004:00/conservation_mode` and
  `lsmod | grep ideapad_laptop`.
- **Plugin not discovered after install**: restart the shell
  (`omarchy restart shell`).
- **Battery % not shown in panel**: the widget reads the UPower display
  device; if no battery is detected it shows "No battery detected".
- **Notification icon shows a black/fuchsia checkerboard**: the notification
  requests the themed icon `battery-caution`; if your icon theme can't
  resolve it (seen with the Vantablack theme, which references a
  `Yaru-gray` icon theme that the `yaru-icon-theme` package doesn't ship),
  the icon slot shows Qt's broken-image placeholder. See
  [Known issues #10](docs/KNOWN-ISSUES.md#10-icon-theme-gap-the-vantablack-theme-references-a-missing-yaru-gray-icon-theme)
  for diagnosis and the verified workaround.

See [Known issues & risks](docs/KNOWN-ISSUES.md) for the full list.

## Uninstall

```bash
omarchy plugin disable pcrisho.power-admin
rm -rf ~/.config/omarchy/plugins/pcrisho.power-admin
```

If you installed the boot service, also remove it:

```bash
sudo systemctl disable --now battery-conservation.service
sudo rm /etc/systemd/system/battery-conservation.service
```

## Documentation

- [Compatibility](docs/COMPATIBILITY.md) — which laptops work, and how to
  adapt the plugin to other vendors/interfaces.
- [Configuration](docs/CONFIGURATION.md) — what is user-configurable (charge
  cap %, notification threshold).
- [Known issues & risks](docs/KNOWN-ISSUES.md) — including what an Omarchy
  update can and cannot break.
- [Architecture](docs/ARCHITECTURE.md) — how the pieces fit together
  (widget → pkexec → sysfs, persistence service, battery-notification clone).
- [Validation](docs/VALIDATION.md) — what was tested and how to reproduce it.

## License

[MIT](LICENSE) © 2026 pcrisho