#!/usr/bin/wpexec

--[[

  WP Virtual HSP/HFP mic

  This is a wireplumber standalone script or plugin that creates a virtual
  mic for every bluetooth device that supports both HSP/HFP and A2DP profiles.

  This virtual mic is automatically connected to the actual mic when it exists
  and the profile is automatically changed to HSP/HFP when the virtual mic is
  connected to a client.

  Thus, you only need to configure the virtual mic as a source in your applications,
  and when these applications connect to the virtual mic the profile is automatically
  changed.


  There are three moving cogs:
    Whenever a BT device that supports both profiles, a virtual node is created
    Whenever the HSP/HFP mic is detected, it's connected to the virtual node
    The BT profile is changed depending on whether or not the virtual node has
    clients
  Wireplumber's bt-profile-switch.lua example was really helpful to learn how to deal
  with its BT API


  Author: Jose Maria Perez Ramos <jose.m.perez.ramos+git gmail>
  License: MIT


  Copyright 2022 Jose Maria Perez Ramos

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
  PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
  OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

]]

local default_config = {profile_debounce_time_ms = 1000} -- setmetatable unavailable :(
local config = ... or {}
for k, v in pairs(default_config) do
  if type(v) == "number" then
    config[k] = tonumber(config[k]) or v
  elseif type(v) == "boolean" then
    local config_v = config[k]
    if type(config_v) == "boolean" then
    elseif config_v == "true" then
      config[k] = true
    elseif config_v == "false" then
      config[k] = false
    else
      config[k] = v
    end
  end
end

sources_om = ObjectManager {
  Interest {
    type = "node",
    Constraint{"media.class", "=", "Audio/Source"},
  }
}

bt_devices_om = ObjectManager {
  Interest {
    type = "device",
    Constraint{"media.class", "=", "Audio/Device"},
    Constraint{"device.api", "=", "bluez5"},
  }
}

-- BT Device Id to Virtual Source node (keeps the reference alive)
local virtual_sources = {}
-- BT Device Id to Virtual Source Port id
local virtual_sources_in_port_id = {}

-- BT Device Id to Virtual Source Out port OM (keeps the reference alive)
local virtual_sources_out_port_om  = {}
-- BT Device Id to profile change debounce timer (keeps the reference)
local debounce_timers = {}

-- BT Device Id to Real Source node id
local real_sources_id = {}
-- BT Device Id to Real Source Port id
local real_sources_port_id  = {}

-- BT Device Id to link (keeps the reference alive)
local links = {}

local function replace_destroy(table, key, value)
  -- setmetatable unavailable :(
  local obj = table[key]
  if type(obj) == "userdata" then
    if obj.request_destroy then
      obj:request_destroy()
    elseif obj.destroy then
      obj:destroy()
    end
  end
  table[key] = value
end

local function maybe_link(device_id)
  local virtual_source = virtual_sources[device_id]
  local virtual_source_port_id = virtual_sources_in_port_id[device_id]
  local real_source_id = real_sources_id[device_id]
  local real_source_port_id = real_sources_port_id[device_id]

  if virtual_source and virtual_source_port_id and real_source_id and real_source_port_id then
    if not links[device_id] then
      local link = Link("link-factory", {
        ["link.input.node"] = virtual_source["bound-id"],
        ["link.input.port"] = virtual_source_port_id,
        ["link.output.node"] = real_source_id,
        ["link.output.port"] = real_source_port_id,
      })
      links[device_id] = link
      link:activate(Feature.Proxy.BOUND)
      Log.debug(link, "Ready")
    end
  else
    replace_destroy(links, device_id, nil)
  end
end

local function change_profile_in_device_node(device, index)
  local callback = function()
    Log.debug(device, "Execute the change")
    device:set_param("Profile", Pod.Object{"Spa:Pod:Object:Param:Profile", "Profile", index = index})
    replace_destroy(debounce_timers, device["bound-id"], nil)
    return false
  end

  local timeout = config.profile_debounce_time_ms
  if timeout > 0 then
    replace_destroy(debounce_timers, device["bound-id"], Core.timeout_add(timeout, callback))
  else
    callback()
  end
end

local function generate_change_profile_based_on_links_fun(device, profile_to_index, decreasing)
  -- Keeps a reference to device as a upvalue, but with the device removal
  -- the om is removed too
  return function(om)
    if virtual_sources_out_port_om[device["bound-id"]] ~= om then
      -- The active OM is not the one this callback is for, it's going to be
      -- deleted shortly
      return
    end
    local n_objects = om:get_n_objects()
    if n_objects == 0 then
      Log.debug(device, "Schedule change to a2dp")
      change_profile_in_device_node(device, profile_to_index["a2dp-sink"])
    elseif n_objects == 1 and not decreasing then
      Log.debug(device, "Schedule change to HSP/HFP")
      change_profile_in_device_node(device, profile_to_index["headset-head-unit"])
    end
  end
end

-- Virtual source node is created for those devices that support
-- both a2dp and headset profiles
-- The node is deleted when the device is removed
bt_devices_om:connect("object-added", function(_, device)
  local profile_to_index = {}
  for profile in device:iterate_params("EnumProfile") do
    profile = profile:parse()
    profile_to_index[profile.properties.name] = profile.properties.index
    if profile_to_index["a2dp-sink"] and profile_to_index["headset-head-unit"] then
      Log.debug(device, "Creating dummy HSP/HFP node")
      local device_id = device["bound-id"]
      local node = Node("adapter", {
        ["factory.name"] = "support.null-audio-sink",
        ["media.class"] = "Audio/Source/Virtual",
        ["node.name"] = (device.properties["device.alias"] or device.properties["device.name"] or "").." virtual HSP/HFP mic",
        ["node.description"] = (device.properties["device.description"] or "").." virtual HSP/HFP mic",
        ["audio.position"] = "MONO",
        ["object.linger"] = false, -- Do not keep node if script terminates
        ["device.id"] = device_id,
      })
      virtual_sources[device_id] = node
      virtual_sources_in_port_id[device_id] = false
      node:connect("ports-changed", function(node)
        Log.debug(device, "Dummy HSP/HFP node ports changed")
        local in_port = node:lookup_port{Constraint{"port.direction", "=", "in"}}
        virtual_sources_in_port_id[device_id] = in_port and in_port["bound-id"]
        maybe_link(device_id)

        -- Monitor number of links for clients in the virtual node
        local out_port = node:lookup_port{Constraint{"port.direction", "=", "out"}}
        if out_port then
          local om = ObjectManager{
            Interest{
              type = "Link",
              Constraint{"link.output.node", "=", node["bound-id"]},
              Constraint{"link.output.port", "=", out_port["bound-id"]},
            }
          }
          virtual_sources_out_port_om[device_id] = om
          om:connect("object-added", generate_change_profile_based_on_links_fun(device, profile_to_index))
          om:connect("object-removed", generate_change_profile_based_on_links_fun(device, profile_to_index, true))
          om:connect("installed", generate_change_profile_based_on_links_fun(device, profile_to_index))
          om:activate()
        else
          virtual_sources_out_port_om[device_id] = nil
          replace_destroy(debounce_timers, device_id, nil)
        end
      end)
      node:activate(Features.ALL)
      break
    end
  end
end)
bt_devices_om:connect("object-removed", function(_, device)
  local device_id = device["bound-id"]
  replace_destroy(virtual_sources, device_id, nil)
  virtual_sources_in_port_id[device_id] = nil
  maybe_link(device_id)
  virtual_sources_out_port_om[device_id] = nil
  replace_destroy(debounce_timers, device_id, nil)
end)

-- When both the virtual node and the headset profile node exist,
-- they are linked together
sources_om:connect("object-added", function(_, source)
  local device_id = tonumber(source.properties['device.id'])
  if not virtual_sources[device_id] then
    return
  end
  -- A Source was added with its device matching one of
  -- the interesting ones
  -- It's assumed that the device event is always triggered
  -- before this source's
  Log.debug(source, "Virtual source found")
  real_sources_id[device_id] = source["bound-id"]
  source:connect("ports-changed", function(source)
    local device_id = tonumber(source.properties['device.id'])
    local port = source:lookup_port{Constraint{"port.direction", "=", "out"}}
    real_sources_port_id[device_id] = port and port["bound-id"]
    Log.debug(source, "Real HSP/HFP node ports changed")
    maybe_link(device_id)
  end)
  local port = source:lookup_port{Constraint{"port.direction", "=", "out"}}
  real_sources_port_id[device_id] = port and port["bound-id"]
  maybe_link(device_id)
end)
sources_om:connect("object-removed", function(_, source)
  local device_id = tonumber(source.properties['device.id'])
  if real_sources_id[device_id] == source["bound-id"] then
    real_sources_id[device_id] = nil
    real_sources_port_id[device_id] = nil
    maybe_link(device_id)
  end
end)

sources_om:activate()
bt_devices_om:activate()

