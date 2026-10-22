-- Prelude: guarantee the parent global table exists before any data file
-- runs, so an early load (e.g. an addon manager force-loading this LoD pack
-- before FabledUI_Nemesis's Core.lua executes) doesn't crash with
-- "attempt to index nil". The parent's Core.lua picks up whatever table is
-- already at _G.FabledUI_Nemesis, so attaching data here is forward-safe.
_G.FabledUI_Nemesis = _G.FabledUI_Nemesis or {}
_G.Nemesis = _G.Nemesis or _G.FabledUI_Nemesis
_G.FabledUI_Nemesis.Data = _G.FabledUI_Nemesis.Data or {}
