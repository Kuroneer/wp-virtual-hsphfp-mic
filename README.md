# WP Virtual HSP/HFP mic

This is a wireplumber standalone script or plugin that creates a virtual
mic for every bluetooth device that supports both HSP/HFP and A2DP profiles.

This virtual mic is automatically connected to the actual mic when it exists
and the profile is automatically changed to HSP/HFP when the virtual mic is
connected to a client.

Thus, you only need to configure the virtual mic as a source in your applications,
and when these applications connect to the virtual mic the profile is automatically
changed.

This script has been tested to work with wireplumber version 0.4.7

## Getting Started

You can run it directly or install it as a wireplumber script.

To run it directly, just make it executable with `chmod +x
wp-virtual-hsphfp-mic.lua` and run it whenever you like it with
`./wp-virtual-hsphfp-mic.lua`

To install it as a script, copy it to your wireplumber scripts directory and
load it from the config. E.g (to install it globally):
```shell
sudo mkdir -p /etc/wireplumber/scripts
sudo wget https://raw.githubusercontent.com/Kuroneer/wp-virtual-hsphfp-mic/master/wp-virtual-hsphfp-mic.lua -O /etc/wireplumber/scripts/wp-virtual-hsphfp-mic.lua
sudo mkdir -p /etc/wireplumber/bluetooth.lua.d
sudo tee <<< 'load_script("wp-virtual-hsphfp-mic.lua")' /etc/wireplumber/bluetooth.lua.d/99-load-hsphfp-virtual-mic.lua
```

You can check the proper locations for the scripts in [the doc](https://pipewire.pages.freedesktop.org/wireplumber/configuration/locations.html)

### Configuration

The following configuration items are available (shown with their defaults):
* `profile_debounce_time_ms: 1000`: ms to wait before executing a profile change


The configuration parameters can be provided to the script from the cli:
`./wp-virtual-hsphfp-mic.lua profile_debounce_time_ms=4000`
or from the configuration files:
`sudo tee <<< 'load_script("wp-virtual-hsphfp-mic.lua", {profile_debounce_time_ms = 4000})' /etc/wireplumber/bluetooth.lua.d/99-load-hsphfp-virtual-mic.lua`

## Authors

* **Jose M Perez Ramos** - [Kuroneer](https://github.com/Kuroneer)

## License

This project is released under the MIT license. Check [LICENSE](LICENSE) for more information.

