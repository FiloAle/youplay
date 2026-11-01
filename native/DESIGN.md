# YouPlay design system

Goal: clean, clear, modern, minimal. It should feel like an app made by Apple.

## Rules

1. **Colors come only from `Palette`.** No hex values, `Color.white`, `Color.gray` or `.opacity()` tints in screens or components.
2. **The palette is semantic and built on system colors.** Light mode, dark mode and Increase Contrast then work without extra code.
3. **Text comes only from `Typography`,** which is built on Dynamic Type styles. No fixed font sizes.
4. **Spacing, corners and motion come only from `Spacing`, `Radius` and `Motion`.**
5. **Use the system control first.** `List`, `NavigationStack`, `TabView`, `.searchable`, `ContentUnavailableView`, `AVPlayerViewController` and Liquid Glass come before anything custom.
6. **A UI pattern used twice becomes a component** in `DesignSystem/Components`.

## Color roles

| Token | Use | System color |
|---|---|---|
| `accent` | Tint, one per screen at most | `systemRed` (the current YouPlay red) |
| `background` | Screens, expanded player | `systemBackground` |
| `surface` | Boxes on top of the background | `secondarySystemBackground` |
| `placeholder` | Images still loading | `tertiarySystemFill` |
| `textPrimary` | Titles, main text | `label` |
| `textSecondary` | Metadata, descriptions | `secondaryLabel` |
| `videoBackground` | Behind video, in both themes | black |
| `badgeBackground`, `badgeText` | Text on top of a thumbnail, in both themes | black 70%, white |

## Components

| Component | Purpose |
|---|---|
| `RemoteImage` | Cached, downsampled image that fills its frame |
| `VideoThumbnail` | 16:9 image with duration or live badge |
| `Avatar` | Round channel image |
| `VideoRow` | Video in any list, with queue and channel actions |
| `ChannelRow` | Channel in any list |
| `ExpandableText` | Long text in a box, collapsed to three lines |
| `IconButton` | Bare icon action with a 44 pt touch target |
| `CircleIcon` | Icon in a neutral circle, as a label for a `Button` or `Menu` |
| `ToastView` | Short confirmation over the content |
| `CategoryMenu` | Picks a followed channel's category |

## Interaction rules

- One primary action per row: tapping a video plays it. Everything else is in its "…" menu, which long press also opens.
- Empty, loading and error states use `ContentUnavailableView` and `ProgressView`.
- Destructive actions use the `.destructive` role, and are always reachable by swipe or menu, never as a standing button.
- Only animate transform and opacity during the player transition, so it never triggers layout.
