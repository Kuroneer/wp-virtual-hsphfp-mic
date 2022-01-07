# WP Virtual HSP/HFP mic

This is a wireplumber standalone script or plugin that creates a virtual
mic for every bluetooth device that supports both HSP/HFP and A2DP profiles.

This virtual mic is automatically connected to the actual mic when it exists
and the profile is automatically changed to HSP/HFP when the virtual mic is
connected to a client.

Thus, you only need to configure the virtual mic as a source in your applications,
and when these applications connect to the virtual mic the profile is automatically
changed.

This script has been tested to work with wireplumber version 0.4.5

## Getting Started

You can run it directly or install it as a wireplumber script.

To run it directly, just make it executable with `chmod +x
wp-virtual-hsphfp-mic.lua` and run it whenever you like it with
`./wp-virtual-hsphfp-mic.lua`

To install it as a script, copy it to your wireplumber scripts directory and
load it from the config. E.g (to install it globally):
```shell
sudo wget https://raw.githubusercontent.com/Kuroneer/wp-virtual-hsphfp-mic/master/wp-virtual-hsphfp-mic.lua -O /usr/share/wireplumber/scripts/wp-virtual-hsphfp-mic.lua
sudo tee <<< 'load_script("wp-virtual-hsphfp-mic.lua")' /usr/share/wireplumber/bluetooth.lua.d/99-load-hsphfp-virtual-mic.lua
```

## Authors

* **Jose M Perez Ramos** - [Kuroneer](https://github.com/Kuroneer)

## License

This project is released under the MIT license. Check [LICENSE](LICENSE) for more information.

