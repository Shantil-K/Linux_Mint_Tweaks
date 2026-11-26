# Battery Charge Limit

Stops the laptop from keeping its battery at 96–100% all the time while it's plugged in, which makes the battery wear out faster.

## Why

A lithium-ion battery is like a spring: holding it fully squeezed (100%) for hours, especially when the laptop is warm, wears it out faster. With the default **Fast** mode on Dell laptops, a plugged-in battery sits at 96–100% almost all the time. It also looks "stuck" at 96, 97 or 98%: the charger stops near full, the laptop runs on AC, and the battery only tops up again after it drifts down a little. That part is normal.

In **Custom** mode the battery only starts charging below **50%** and stops at **90%**. For a laptop that's mostly plugged in, this keeps noticeably more of the battery's original capacity over a year or two.

## Usage

```bash
./battery_charge_mode.sh                 # Show the current mode and limits
./battery_charge_mode.sh custom          # Charge only between 50% and 90%
./battery_charge_mode.sh custom 60 80    # Choose your own limits
./battery_charge_mode.sh standard        # Charge to 100% (e.g. the night before a trip)
./battery_charge_mode.sh fast            # Back to the Dell default
```

It asks for your password (pkexec) because the settings are written to `/sys`.

Tip: if you're mostly plugged in, leave it on **custom**. Before a long day away from a charger, switch to **standard**, then switch back afterwards.

## Manual Commands (Dell)

```bash
# Limits: start charging below 50%, stop at 90%
echo 50 | sudo tee /sys/class/power_supply/BAT0/charge_control_start_threshold
echo 90 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold

# Use the limits (Dell only applies them in Custom mode)
echo Custom | sudo tee /sys/class/power_supply/BAT0/charge_types

# Check
cat /sys/class/power_supply/BAT0/charge_types    # current mode is in [brackets]
```

## Does it stay after a reboot?

On Dell laptops, yes: the setting is stored in the laptop's firmware. If it ever goes back to Fast, set it in the BIOS instead: press **F2** at boot → **Power Management** → **Primary Battery Charge Configuration** → **Custom**.

## Supported Laptops

Any laptop whose kernel driver exposes `charge_types` and/or `charge_control_start_threshold` / `charge_control_end_threshold` in `/sys/class/power_supply/BAT*`. That includes Dell (tested on a G3 3590), ThinkPad, ASUS and others. Some laptops only support a stop limit. In that case the start limit is skipped.
