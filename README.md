# Telegram Playground

A fork of [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS) used to prototype a **quick attach** flow. Everything else is upstream; the build instructions are in [`CLAUDE.md`](CLAUDE.md).

## What's different from upstream

- **Hold the paperclip** — a fan of your latest photos pops out of the composer; release on one and it flies into the input as a tile.
- **Media tiles in the composer** — attached photos and videos sit in a strip inside the input: reorder by drag, remove with ×, videos loop muted, spoilers show blurred under dust.
- **Post preview** — an eye button opens the message exactly as it will land in the chat (album, caption, spoilers), with a pinned Send.
- **Attachment sheet as a mirror of the composer** — the picker opens with the composer's selection, a chevron hands the selection back, the close cross turns into it once something is picked.
- **Bent grid edge** — adapted from the emoji picker's edge warp. One live portal view of the photo grid bends through a cached 24×6 mesh, with full perspective and no bottom fade. Aligned clipping removes the seam; pre-projected perspective removes the jump as the sheet opens.
- **Album editing** — long-press any tile of an album to edit it: add, remove, reorder media, toggle spoilers, keep the caption; the edit applies locally.
- **Demo mode** — a bundle-id-gated demo account with seeded dialogs and media, so the flow can be tried without a real login.

## How the edge warp works

The emoji picker approximates a curve with eight narrow, 3D-rotated portal strips and fades the content toward the bottom. Large photo tiles make joins and misaligned grid lines more visible, so the media picker uses **one live portal with mesh deformation**. The portal mirrors the existing grid; it does not take screenshots or duplicate the photo data.

The mesh has 24 rows and 6 columns (175 vertices, 144 faces). Its perspective is projected into the vertices ahead of rendering and its geometry is rebuilt only when the size, bend height, or perspective changes. This keeps the bend stable while the attachment sheet scales into place. Rasterization at screen scale and trilinear filtering smooth the tile edges; the bottom stays visible without a fade or white gap.

Both approaches use Apple's private `_UIPortalView`. The mesh path also uses private `CAMutableMeshTransform` / `CAMeshTransform` and the layer's `meshTransform` property. These APIs carry compatibility and App Store review risks; this is a prototype, not a public-API-only implementation.

## Performance measurement

On a physical **iPhone 15 Pro Max, iOS 27.0, Release build 100073**, a manual scroll with warp enabled produced **1,317 presented frames over 22.60 seconds: 58.28 FPS averaged across the entire recording**. The camera tile stayed offscreen, and no camera YUV-plane programming was present in the trace. Thermal state remained nominal.

This counts actual presented frames, cross-checked between IOMFB and Core Animation, rather than `CADisplayLink` callbacks. The recording includes pauses between gestures. It does **not** establish stable 60 FPS, a speedup over the emoji picker's implementation, or the incremental cost of warp; no warp-off baseline was measured.

See the [physical-device report and frame data](docs/performance/media-picker-100073/README.md). The [earlier simulator report](docs/performance/media-picker-100071/README.md) measures callback cadence and is not an FPS baseline.
