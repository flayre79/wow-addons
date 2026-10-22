-- Prelude: guarantee the parent global table exists before any data file
-- runs, so an early load (e.g. an addon manager force-loading this LoD pack
-- before FabledUI_Crafty's Core.lua executes) doesn't crash with
-- "attempt to index nil". The parent's Core.lua picks up whatever table is
-- already at _G.FabledUI_Crafty, so attaching data here is forward-safe.
_G.FabledUI_Crafty = _G.FabledUI_Crafty or {}
