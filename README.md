# Telegram Playground

A fork of [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS) used to prototype a **quick attach** flow. Everything else is upstream; the build instructions are in [`CLAUDE.md`](CLAUDE.md).

## What's different from upstream

- **Hold the paperclip** — a fan of your latest photos pops out of the composer; release on one and it flies into the input as a tile.
- **Media tiles in the composer** — attached photos and videos sit in a strip inside the input: reorder by drag, remove with ×, videos loop muted, spoilers show blurred under dust.
- **Post preview** — an eye button opens the message exactly as it will land in the chat (album, caption, spoilers), with a pinned Send.
- **Attachment sheet as a mirror of the composer** — the picker opens with the composer's selection, a chevron hands the selection back, the close cross turns into it once something is picked.
- **Bent grid edge** — the picker's bottom rows curl away in 3D (eight portal slices of the grid in an arc), tuned for a full-width photo grid: half perspective, no fade over the glass sheet.
- **Album editing** — long-press any tile of an album to edit it: add, remove, reorder media, toggle spoilers, keep the caption; the edit applies locally.
- **Demo mode** — a bundle-id-gated demo account with seeded dialogs and media, so the flow can be tried without a real login.
