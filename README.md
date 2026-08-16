# Power Administrator — Omarchy plugin

Bar widget to toggle the **Lenovo battery conservation mode** (80% charge cap)
on `ThinkBook`/`IdeaPad` laptops from the Omarchy bar.

## What it does

- Shows the current state in the bar: `󰂅` = limit active (stops at 80%),
  `󰁹` = full charge allowed.
- **Left click** on the icon: toggle the limit (a polkit prompt asks for your
  password/fingerprint — the change needs root).
- **Right click**: open the panel with status, battery %, and explicit
  `Limit to 80%` / `Full charge` buttons.
- Re-reads the state every 30s, so it stays honest even if the value changes
  behind its back (e.g. `echo 1 > .../conservation_mode` from a terminal).

## Requirements

- Omarchy (Hyprland/Quickshell shell)
- A Lenovo laptop exposing
  `/sys/bus/platform/devices/VPC2004:00/conservation_mode`
- `pkexec` (polkit agent — Omarchy ships `omarchy.polkit`, enabled by default)

## Install

```bash
./install.sh
```

This copies the plugin to `~/.config/omarchy/plugins/pcrisho.power-admin/`,
rescans the plugin registry, and enables it in the bar's right section.

If the shell is slow to answer IPC calls (seen on this machine), the script
uses a 15s IPC timeout automatically; override with
`OMARCHY_SHELL_IPC_TIMEOUT=30s ./install.sh`.

## Usage

| Action | Effect |
|---|---|
| Left click icon | Toggle charge limit (prompts via polkit) |
| Right click icon | Open panel |
| Panel buttons | Explicit `Limit to 80%` / `Full charge` |

The 80% limit is re-applied on every boot by `battery-conservation.service`
(set up separately). Disabling it from the widget only lasts until the next
restart — by design, so the battery stays protected by default.

## IPC

```bash
omarchy shell pcrisho.power-admin state      # on|off
omarchy shell pcrisho.power-admin toggle
omarchy shell pcrisho.power-admin setLimit on
```

## Uninstall

```bash
omarchy plugin disable pcrisho.power-admin
rm -rf ~/.config/omarchy/plugins/pcrisho.power-admin
```

## Notes / limitations

- The toggle needs root: `pkexec` shows the polkit prompt. If no prompt
  appears, check that the Omarchy polkit agent is running (`omarchy plugin
  list` → `omarchy.polkit` should be enabled).
- Hardcoded for Lenovo's `VPC2004:00` ACPI path; tweak `sysPath` in
  `Panel.qml` for other vendors.