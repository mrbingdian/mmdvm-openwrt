-- Copyright 2019 BD7MQB <bd7mqb@qq.com>
-- This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 2.0

local sys   = require "luci.sys"
local fs    = require "nixio.fs"
local json = require "luci.jsonc"

local m, s, o = ...

local mmdvm = require("luci.model.mmdvm")
local http  = require("luci.http")
-- local conffile = uci:get("mmdvm", "mmdvmhost", "conf") or "/etc/MMDVM.ini"

m = Map("mmdvm", translate("MMDVM Configuration"), translate("Here you can configure the basic aspects of your device like its callsign or the operating modes."))
m.on_after_commit = function(self)
	if self.changed then	-- changes ?
        changes = self.uci:changes("mmdvm")
        -- if MMDVM.ini changed?
        if mmdvm.uci2ini(changes) then
            sys.call("env -i /etc/init.d/mmdvmhost restart >/dev/null")
        end
	end
end

-- Initialize uci file using ini if needed, MUST called at the fist run.
mmdvm.ini2uci(m.uci)

--
-- General Properties
--
s = m:section(NamedSection, "General", "mmdvmhost", translate("General Settings"))
s.anonymous = true
s.addremove = false

o = s:option(Value, "Callsign", translate("Callsign"), translate("Your Callsign in uppercase"))
o = s:option(Value, "Id", translate("ID"), translate("Your DmrId or DmrId + <abbr title=\"ex. 460713301\">2 digitals</abbr>"))
o.optional    = true
o.datatype    = "uinteger"

o = s:option(ListValue, "Duplex", translate("Duplex/Simplex"), translate("Duplex or Simplex mode"))
o:value("1", "Duplex")
o:value("0", "Simplex")

o = s:option(Value, "NetModeHang", translate("NetModeHang"), translate("Seconds waiting between 2 modes from <abbr title=\"transmision from network\">Net</abbr>"))
o.datatype    = "uinteger"
o = s:option(Value, "RFModeHang", translate("RFModeHang"), translate("Seconds waiting between 2 modes from <abbr title=\"transmision from local RF\">RF</abbr>"))
o.datatype    = "uinteger"

--
-- Info Properties
--
s = m:section(NamedSection, "Info", "mmdvmhost", translate("Infomation Settings"), translate("Those infomation will show up at brandmeister.network if you enable DMR mode"))
s.anonymous   = true

o = s:option(Value, "RXFrequency", translate("RXFrequency"), translate("Use the format <abbr title=\"the Unit is Hz\">434500000</abbr>, in Hz"))
o.optional    = true
o.datatype    = "uinteger"
o = s:option(Value, "TXFrequency", translate("TXFrequency"), translate("Use the same format as RXFrequency"))
o.optional    = true
o.datatype    = "uinteger"
o = s:option(Value, "Latitude", translate("Latitude"), translate("e.g. 22.10 N"))
o = s:option(Value, "Longitude", translate("Longitude"), translate("e.g. 114.3 E"))
o = s:option(Value, "Height", translate("Height"), translate("e.g. 110 Meters"))
o.optional    = true
o.datatype    = "uinteger"
o = s:option(Value, "Power", translate("TXPower"), translate("e.g. 1 Watt"))
o.optional    = true
o.datatype    = "uinteger"
o = s:option(Value, "Location", translate("Location"))
o = s:option(Value, "Description", translate("Description"))
o = s:option(Value, "URL", translate("URL"))

--
-- Modem Properties
--
s = m:section(NamedSection, "Modem", "mmdvmhost", translate("Modem Settings"), translate("Edit modem port, Rx/Tx offset and etc."))
s.anonymous   = true
o = s:option(ListValue, "Port", translate("Port"), translate("The port of Modem"))
o:value("NullModem", "NullModem")
if fs.access("/dev/ttyS1") then o:value("/dev/ttyS1") end
if fs.access("/dev/ttyUSB0") then o:value("/dev/ttyUSB0") end
if fs.access("/dev/ttyACM0") then o:value("/dev/ttyACM0") end
if fs.access("/dev/ttyAMA0") then o:value("/dev/ttyAMA0") end

o = s:option(Value, "RXOffset", translate("RXOffset"))
o = s:option(Value, "TXOffset", translate("TXOffset"))

o = s:option(Value, "RSSIMappingFile", translate("RSSIMappingFile"))

--
-- DMR Properties
--
s = m:section(NamedSection, "DMR", "mmdvmhost", translate("DMR Settings"))
s.anonymous   = true

o = s:option(Flag, "Enable", translate("Enable DMR Mode"))
o.rmempty = false
function o.write(self, section, value)
    AbstractValue.write(self, section, value)
    self.map.uci:set("mmdvm", "DMR_Network", "Enable", value)
end

o = s:option(ListValue, "ColorCode", translate("ColorCode"), translate("Personal hotspots typically use color code 1"))
for i=1,12,1 do
    o:value(i, i)
end
o = s:option(Flag, "SelfOnly", translate("SelfOnly"), translate("Only the callsign you entered above shall pass in DMR mode"))
o.rmempty = false

o = s:option(Flag, "DumpTAData", translate("DumpTAData"), translate("Which enables \"Talker Alias\" information to be received by radios that support this feature"))
o.rmempty = false

--
-- DMR Network
--
s = m:section(NamedSection, "DMR_Network", "mmdvmhost")
s.anonymous   = true
o = s:option(ListValue, "Address", translate("DMR Server"))
for _, r in ipairs(mmdvm.get_bm_list()) do
    o:value(r[3], "BM" .. r[1] .. " " .. r[2])
end

--
-- YSF Properties
--
s = m:section(NamedSection, "System_Fusion", "mmdvmhost", translate("YSF Settings"))
s.anonymous   = true

o = s:option(Flag, "Enable", translate("Enable YSF Mode"))
o.rmempty = false
function o.cfgvalue(self)
    return sys.init.enabled("ysfgateway")
        and self.enabled or self.disabled
end
function o.write(self, section, value)
    if value == self.enabled then
        sys.init.enable("ysfgateway")
        sys.init.enable("ysfparrot")
        sys.call("env -i /etc/init.d/ysfgateway start >/dev/null")
        sys.call("env -i /etc/init.d/ysfparrot start >/dev/null")
    else
        sys.call("env -i /etc/init.d/ysfgateway stop >/dev/null")
        sys.call("env -i /etc/init.d/ysfparrot stop >/dev/null")
        sys.init.disable("ysfgateway")
        sys.init.disable("ysfparrot")
    end
    AbstractValue.write(self, section, value)
    self.map.uci:set("mmdvm", "System_Fusion_Network", "Enable", value)
end

o = s:option(Flag, "SelfOnly", translate("SelfOnly"), translate("Only the callsign you entered above shall pass in YSF mode"))
o.rmempty = false

s = m:section(NamedSection, "YSFG_Network", "ysfgateway")
s.anonymous   = true
o = s:option(ListValue, "Startup", translate("Startup Reflector"))
for _, r in ipairs(mmdvm.get_ysf_list()) do
    o:value(r[2], r[1] .. " - " .. r[2])
end

o = s:option(Value, "InactivityTimeout", translate("InactivityTimeout"), translate("Minutes to disconect when idle"))
o.optional    = false
o.datatype    = "uinteger"
o = s:option(Flag, "Revert", translate("Revert to Startup"), translate("Revert to Startup reflector when InactivityTimeout"))
o.rmempty = false

--
-- P25 Properties
--
s = m:section(NamedSection, "P25", "mmdvmhost", translate("P25 Settings"))
s.anonymous   = true

o = s:option(Flag, "Enable", translate("Enable P25 Mode"))
o.rmempty = false
function o.cfgvalue(self)
    return sys.init.enabled("p25gateway")
        and self.enabled or self.disabled
end
function o.write(self, section, value)
    if value == self.enabled then
        sys.init.enable("p25gateway")
        sys.init.enable("p25parrot")
        sys.call("env -i /etc/init.d/p25gateway start >/dev/null")
        sys.call("env -i /etc/init.d/p25parrot start >/dev/null")
    else
        sys.call("env -i /etc/init.d/p25gateway stop >/dev/null")
        sys.call("env -i /etc/init.d/p25parrot stop >/dev/null")
        sys.init.disable("p25gateway")
        sys.init.disable("p25parrot")
    end
    AbstractValue.write(self, section, value)
    self.map.uci:set("mmdvm", "P25_Network", "Enable", value)
end

o = s:option(Value, "NAC", translate("NAC"), translate("Network Access Control"))
o.optional    = false
o.datatype    = "uinteger"

o = s:option(Flag, "SelfOnly", translate("SelfOnly"), translate("Only the callsign you entered above shall pass in P25 mode"))
o.rmempty = false

o = s:option(Flag, "OverrideUIDCheck", translate("OverrideUIDCheck"), translate("Only vaild IDs shall pass on RF transmition by unchecked this"))
o.rmempty = false

s = m:section(NamedSection, "P25G_Network", "p25gateway")
s.anonymous   = true
o = s:option(ListValue, "Startup", translate("Startup Reflector"))
for _, r in ipairs(mmdvm.get_p25_list()) do
    o:value(r[1], r[1] .. " - " .. r[2])
end

o = s:option(Value, "InactivityTimeout", translate("InactivityTimeout"), translate("Minutes to disconect when idle"))
o.optional    = false
o.datatype    = "uinteger"
o = s:option(Flag, "Revert", translate("Revert to Startup"), translate("Revert to Startup reflector when InactivityTimeout"))
o.rmempty = false

return m
