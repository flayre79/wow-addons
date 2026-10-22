# FabledUI - Iris

Version documented here: **1.5.0**

## Purpose

Iris is the lightweight chat utility for the FlayreDev suite. It is designed to cover the practical daily-driver pieces many players want from larger chat mods without dragging in a sprawling chat-overhaul monster.

Primary goals:

- copy visible chat text from any chat frame
- provide a cleaner export format for readable pastes
- extract URLs from chat text for quick copying
- maintain a persistent local searchable history buffer
- stay lightweight and useful instead of becoming a full chat rewrite

---

## Current Feature Set

### 1. Chat Frame Launcher Button

Iris adds a small launcher button beside supported chat tabs.

**Behavior**
- Left-click opens the selected default copy mode for that specific chat frame
- Right-click opens the global Iris history window
- Tooltip explains both actions

**Notes**
- The launcher is anchored beside the chat tab instead of colliding with Blizzard’s chat-side utility buttons
- If no tab is available, Iris falls back to a safe chat-frame anchor

---

### 2. Copy Modes

Iris supports three copy/export modes from the active or selected chat frame.

#### Raw Copy
Displays the captured chat lines as close to the original chat payload as practical.

Use this when you want:
- original line formatting preserved as much as possible
- direct inspection of what the frame actually captured
- a lower-touch export

#### Clean Copy
Converts chat output into more readable text.

Current cleaning behavior:
- resolves formatted chat strings into readable display text
- strips color codes
- strips texture/icon tags
- strips atlas/image tags
- unwraps WoW hyperlink wrappers while preserving readable link text
- normalizes whitespace

Use this when you want:
- clean notes
- readable logs
- pasting into Discord, documents, tickets, or markdown without goblin markup everywhere

#### URLs Only
Extracts likely URLs and email-style addresses from the captured lines.

Current extraction behavior:
- `http://...`
- `https://...`
- `www....`
- `name@example.com`
- duplicates are removed
- trailing punctuation is trimmed where practical

Use this when you want:
- website links mentioned in chat
- addon/help links
- copied references without the rest of the conversation clutter

---

### 3. Global History Buffer

Iris maintains a local persistent history buffer.

**Current behavior**
- stores versioned metadata-aware history entries
- retains source event, bucket, author, capture time, channel names, raw text, cleaned text, and extracted URLs
- safely migrates the legacy string-only history buffer without changing its visible lines
- persists between reload/logout sessions
- searchable in the Iris window
- history size is configurable
- oldest lines are discarded first when the cap is reached

**Search behavior**
- plain text search
- case-insensitive matching
- ignores some common markup noise while searching

---

### 4. Supported History Capture Buckets

Iris can currently capture the following categories into the local history buffer:

- SAY
- YELL
- EMOTE
- WHISPER
- BNET
- PARTY
- RAID
- RAID_WARNING
- INSTANCE
- GUILD
- OFFICER
- CHANNEL
- SYSTEM
- CREATURE

**Creature bucket includes** common monster/boss speech-style chat events such as:
- monster say
- monster yell
- monster emote
- monster whisper
- boss emote/whisper style events

---

### 5. Main Iris Window

The Iris window contains:

- **Raw Copy** tab
- **Clean Copy** tab
- **URLs Only** tab
- **History** tab
- **Settings** tab
- **Search** box (history mode)
- **Select All** button
- **Copy Active** button
- **Settings** button (same destination as the tab)
- **Scrollable multiline export area**
- **Scrollable in-window settings surface**
- **Line count readout**

**Mode behavior**
- Raw / Clean / URLs operate on the active or chosen chat frame
- History opens the persistent global history buffer
- Settings swaps the export area for the controls; nothing leaves the window
- Search is shown only in History mode
- Select All / Copy Active / the line count are hidden in Settings mode

---

## Commands

### Slash Commands

- `/iris` → open history
- `/iris history` → open history
- `/iris copy` → open raw copy from the active chat frame
- `/iris raw` → open raw copy from the active chat frame
- `/iris clean` → open clean copy from the active chat frame
- `/iris urls` → open URLs-only extraction from the active chat frame
- `/iris url` → alias for URLs-only extraction
- `/iris clear` → clear saved global history
- `/iris settings` → open Iris settings

---

## Settings and Controls

All controls below live on the **Settings** tab of the Iris window. Iris
registers **no** category under Blizzard's *Options → AddOns* list. Nexus opens
this tab through `settingsPath = "Settings.Open"` on its Iris registry entry, so
`I.Settings:Open()` is a contract and must keep its name.

### General Settings

- **Enable Global History Capture**
  - turns the persistent history collector on or off

- **Show Chat Tab Buttons**
  - shows or hides the Iris launcher buttons on chat tabs

- **Include Timestamps In Saved History**
  - stores timestamps with captured history lines

### Default Left-Click Copy Mode

Radio options:
- Raw
- Clean
- URLs

This controls what the launcher button does on left-click.

### History Size Slider

Controls how many history lines Iris stores locally.

Range:
- minimum: 50
- maximum: 5000

### Capture Channel Toggles

Per-category toggles exist for:
- SAY
- YELL
- EMOTE
- WHISPER
- BNET
- PARTY
- RAID
- RAID_WARNING
- INSTANCE
- GUILD
- OFFICER
- CHANNEL
- SYSTEM
- CREATURE

---

## Interaction Summary

### Chat Tab Button
- **Left-click**: open selected default copy mode for that frame
- **Right-click**: open history

### Main Window Controls
- **Raw Copy**: show raw export for active frame
- **Clean Copy**: show readable cleaned export for active frame
- **URLs Only**: show extracted URLs from active frame
- **History**: show persistent searchable buffer
- **Search**: filter history results
- **Select All**: highlight all text in the export box
- **Copy Active**: reopen the active chat frame using the selected default copy mode
- **Settings**: show the Iris settings surface inside the Iris window

---

## What Iris Does Not Currently Try To Be

Iris is **not** currently intended to be:

- a full Prat-scale chat rewrite
- a visual restyling addon for fonts/chat frame skinning
- a channel name formatter
- a timestamp styling system
- a player name decoration engine
- a hyperlink click interceptor
- a combat log replacement

That restraint is intentional. The addon is being kept focused.

---

## Backlog / Future Options

These are future candidates, not current commitments.

### Priority Backlog

#### 1. Advanced Search Filters
Possible additions:
- filter by category
- filter by sender
- filter by time range
- newest-first / oldest-first toggles
- exact match mode
- URLs-only search view on history

#### 2. Per-Frame History Views
Instead of only one global history buffer, Iris could optionally maintain:
- global history
- per-frame history snapshots
- temporary whisper/BNet buckets

#### 3. Better Link Normalization
Improve how links are exported in clean mode.

Possibilities:
- preserve both display text and underlying WoW link type
- detect addon links vs item links vs player links
- export link summaries in a more structured format

#### 4. URL Detection Expansion
Possible improvements:
- broader URL patterns
- safer punctuation trimming
- optional auto-prefix normalization for `www.` links
- URL extraction from history mode, not just current frame mode

### Secondary Backlog

#### 5. Export Actions
Potential additions:
- Copy Clean button
- Copy URLs button
- Save to SavedVariables snapshot
- export to named history note blob

#### 6. Better Empty-State Messaging
Examples:
- no URLs found in current capture
- history disabled
- no matching search results
- hidden launcher buttons reminder

#### 7. Optional Minimap or Suite Entry Point Integration
Only if needed for convenience.

#### 8. Copy Range Controls
Examples:
- last 25 lines
- last 50 lines
- last 100 lines
- full visible buffer

#### 9. Search Highlighting
Highlight matching terms inside history results.

### Nice-to-Have Later

- import/export history archive
- saved snippets or pinned notes
- compact mode window
- suite-wide theme polish
- DataVault analytics hooks if needed later

---

## Design Direction Guardrails

Iris should continue to prioritize:

1. lightweight utility value
2. stable Retail-safe behavior
3. clean copy/export quality
4. local searchable history
5. low-friction controls

It should avoid mutating into a bloated all-things-chat Frankenstein unless that becomes an explicit project decision.
