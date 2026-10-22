# FabledUI - Artemis

**Quest intelligence tracker for Retail 12.0+**

Artemis is the suite's quest operations hub. It replaces the old shell tracker with a modular tracker that groups quests intelligently, builds a lightweight checklist from recurring content, and routes selected work into Odyssey instead of TomTom.

## Included in this build

- Modular file layout instead of a single giant tracker blob
- DataVault-aware schema v2 storage with legacy migration from the old flat profile
- Focus quest mode with Odyssey route handoff
- Collapsible sections with character-scoped persistence
- Current-zone, focus, world quest, and checklist display modes
- Derived checklist section for daily, weekly, and expiring activities
- Tracked profession recipes with a live have/need count per required reagent
- Optional tracked achievement section
- Secure quest item button support where Blizzard exposes a quest item
- Settings API registration for Artemis options

## Controls

- **Left-click** a quest row: Open quest details
- **Right-click** a quest row: Toggle focus
- **Middle-click** a quest or checklist row: Push it to Odyssey
- **Click a section header**: Collapse or expand it
- **Left-click** a recipe row: Open it in the profession window
- **Right-click** a recipe row: Untrack the recipe
- **/artemis**: Toggle the tracker
- **/artemis settings**: Open settings
- **/artemis status**: Report storage backend, loaded modules, and any events the client refused
- **/artemis refresh**: Force a refresh
- **/artemis clearfocus**: Clear the current focus quest

## Storage

Artemis stores account settings, character focus state, collapsed sections, and checklist state through DataVault when available. It falls back to local saved variables when DataVault is missing.

## Notes

This version adds Odyssey route mode controls (append, replace, focus), checklist template toggles, and richer quest badges. Odyssey remains a soft bridge: if it is not loaded, Artemis still works and simply disables route handoff behavior.


## Child Modules
- `FabledUI_Artemis_Checklist` - checklist generation and manual entry handling.
- `FabledUI_Artemis_Odyssey` - Odyssey routing bridge.
