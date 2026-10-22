# Harvest — imported node locations

Generated dataset of gathering-node locations. **Do not edit by hand**; it is
produced by `tools/data-pipeline/sources/harvest-nodes-importer.py` and any
manual change is lost on the next pipeline run.

## What it is

Factual observations about the game world: a resource of a given type exists at
a given map and position. Nothing else.

Each record is `mapID`, `x`, `y`, and one of Harvest's existing layer names
(`herb`, `ore`, `fish`, `treasure`, `lumber`). Coordinates are 0–1 fractions,
matching what `C_Map.GetPlayerMapPosition` returns and what the rest of the
addon stores — there is no second coordinate convention in Harvest.

## Layout

```
FabledUI_Harvest/Data/NodeIndex.lua        always loaded — routing table only
FabledUI_Harvest_Data_<lo>_<hi>/           one LoadOnDemand addon per mapID band
    Zone_<mapID>.lua                       one file per zone
    FabledUI_Harvest_Data_<lo>_<hi>.toc
```

The dataset is far too large to keep resident, so it is split two ways. Zone
files keep each map's nodes separately reviewable, and the bands are what
actually gets loaded — entering a zone pulls in one band, not the whole set.

`NodeIndex.lua` is small enough to always ship with the base addon. It maps each
map ID to its band addon plus per-layer node counts, so the runtime can answer
"is there anything here, and does the player have that layer enabled?" without
paying for an addon load at all. That matters because most maps in the game have
no data, and the index is checked on every zone change.

## Schema

```lua
-- Data/NodeIndex.lua
H.NodeIndex = {
    __version     = "YYYY-MM-DD-nodesN",
    __dataVersion = 1,
    zones = {
        [2215] = { addon = "FabledUI_Harvest_Data_2200_2399", herb=2441, ore=2151, ... },
    },
}

-- FabledUI_Harvest_Data_2200_2399/Zone_2215.lua
D[2215] = {
    herb = { 0.6430,0.5980, 0.5170,0.4420, ... },  -- flat x,y pairs
}
```

Layers are flat lists of alternating x and y rather than a table per node. At
this scale a table per node is a great deal of allocation for data that is only
ever read positionally; `H:ForEachImportedNode` steps the list in twos.

## How it is used

Imported nodes are **read-only reference data**. They are never written into
`H.db`, which holds only what the player personally gathered. Keeping them
separate is what lets a player capture carry a real `lastSeen`, age on the
radar, and survive an export — none of which is true or meaningful for an
imported coordinate.

Consumers: `NodeData.lua` (loading and lookup), `MapProvider.lua` (world-map
pins) and `RadarHUD.lua` (radar blips, distance-prefiltered). All three respect
the layer toggles and the `showImportedNodes` setting; turning that setting off
stops the band addons being loaded at all, so it is a memory switch as well as a
display one.

## Provenance and scope

Only the factual coordinates were extracted. The import deliberately discards
the source's own numeric node IDs — they encode a taxonomy Harvest neither needs
nor wants to inherit — along with everything else about how that project stores
or loads its data.

No third-party code, loader, module structure, database implementation, or file
is incorporated, and nothing at runtime depends on any other addon being
installed. The generated files are a newly produced dataset in a schema designed
here, not a copy or a modified form of another project's database.

Gas-cloud and archaeology nodes exist upstream but are **not** imported: Harvest
has no layer for either, and adding data the UI has no filter to turn off would
put nodes on the map the player cannot remove.

## Regenerating

```powershell
python tools/data-pipeline/sources/harvest-nodes-importer.py
# or as part of the full pipeline
python tools/data-pipeline/run-all.py
```

The importer prints per-file node counts, dropped duplicates, and per-band
totals. `FabledUI_Harvest/tests/node_data.lua` asserts the totals exactly, so a
regenerate that loses zones or nodes fails the harness rather than silently
shipping a smaller dataset — update the expected counts there deliberately when
the numbers are meant to change.
