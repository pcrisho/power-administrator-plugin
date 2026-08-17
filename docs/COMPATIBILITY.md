# Compatibility

## TL;DR

The plugin as shipped works **only** on Lenovo laptops with the
`ideapad_laptop` kernel driver (ThinkBook / IdeaPad / Legion models that
expose `VPC2004:00/conservation_mode`). The same concept exists on other
brands, but through **different sysfs interfaces** — see the table below.

## Vendor matrix

| Vendor / family | Kernel driver | Interface | Configurable %? | Works out of the box? |
|---|---|---|---|---|
| **Lenovo IdeaPad / ThinkBook / Legion** (this plugin) | `ideapad_laptop` | `/sys/bus/platform/devices/VPC2004:00/conservation_mode` (0/1) | No — firmware-fixed (~80%, some Legion models 60%) | ✅ Yes |
| Lenovo ThinkPad | `thinkpad_acpi` | `/sys/class/power_supply/BAT0/charge_control_{start,end}_threshold` | Yes (0–100) | ⚠️ Different interface |
| ASUS | `asus-wmi` | `/sys/class/power_supply/BAT0/charge_control_end_threshold` | Yes (some models: only 40/60/80/100) | ⚠️ Different interface |
| Dell (kernel ≥ 6.12) | `dell_laptop` | `charge_control_end_threshold` (via EC) | Yes (55–100) | ⚠️ Different interface |
| Framework | `cros_charge-control` (module option required) | `charge_control_end_threshold` | Yes (1–100) | ⚠️ Different interface |
| LG | `lg_laptop` | `charge_control_end_threshold` | Partial (discrete values) | ⚠️ Different interface |
| Huawei | `huawei-wmi` | `charge_control_{start,end}_threshold` | Yes | ⚠️ Different interface |
| MSI / System76 / Tuxedo | `msi-ec`, `system76_acpi`, … | vendor-specific | Partial | ⚠️ Different interface |
| HP / Acer | — | none exposed to Linux | No | ❌ Not supported (no interface at all) |

Sources: kernel drivers `drivers/platform/x86/*`, TLP documentation, Arch Wiki.

## How to verify on any machine

```bash
# Binary toggle (Lenovo conservation mode style)
ls /sys/bus/platform/devices/VPC2004:00/conservation_mode 2>/dev/null

# Percentage-based threshold (ThinkPad/ASUS/Dell/Framework style)
cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null

# Does UPower report threshold support?
upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep -i threshold
```

If `charge_control_end_threshold` exists, the laptop supports a
**user-configurable percentage**; if only `conservation_mode` exists, the
percentage is **fixed by the firmware** (see Configuration).

## Adapting the plugin to another vendor

1. Point `sysPath` in `Panel.qml` at the correct attribute.
2. Change the write command in `Panel.qml` from a 0/1 echo to the percentage
   value (e.g. `echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold`).
3. Update the fixed "80%" strings (or better: read the current value from the
   sysfs attribute before rendering).
4. Re-check persistence: some vendors reset the threshold on every boot
   (e.g. ASUS) and need the systemd service approach from Architecture.

## Known compatibility caveats

- Some Lenovo non-ThinkPad models **ignore** the conservation mode setting
  entirely (documented by TLP maintainers).
- Dell requires kernel ≥ 6.12 and the EC charge type set to "Custom".
- Framework requires the `probe_with_fwk_charge_control=1` module option and
  kernel ≥ 6.17 (EC firmware v2 changes broke the driver).
- LG Gram thresholds broke in kernel 6.9, fixed in 6.10.7+.