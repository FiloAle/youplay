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
| `accent` | App tint: icons in toolbars and menus, buttons, selected tab | `systemRed` (the current YouPlay red) |
| `background` | Screens, expanded player | `systemBackground` |
| `surface` | Boxes on top of the background | `secondarySystemBackground` |
| `placeholder` | Images still loading | `tertiarySystemFill` |
| `textPrimary` | Titles, main text | `label` |
| `textSecondary` | Metadata, descriptions | `secondaryLabel` |
| `videoBackground` | Behind video, in both themes | black |
| `badgeBackground`, `badgeText` | Text and icons on top of images and video, in both themes | black 70%, white |
| `shadow` | Under the floating mini player | black 30% |

## Spacing rhythm

The closer two things are related, the closer they sit. Each level is visibly larger than the one below it.

| Gap | Between | Token |
|---|---|---|
| 2 pt | Lines of the same metadata | `xxs` |
| 4 pt | A title and its metadata | `xs` |
| 12 pt | A section title and its first row | `xs` + row inset |
| 16 pt | Blocks of a header, adjacent rows, screen margins | `lg`, or `contentRow` twice |
| 32 pt | Sections | `SectionTitle`, `xl` + row inset |

Every list uses `contentList()`, and every row `contentRow()` or `SectionTitle`, so these gaps can't drift between screens. There are no separators: lists are held together by spacing.

## Components

| Component | Purpose |
|---|---|
| `RemoteImage` | Cached, downsampled image that fills its frame |
| `VideoThumbnail` | 16:9 image with duration or live badge |
| `Avatar` | Round channel image |
| `VideoRow` | Video in any list, with queue and channel actions |
| `ChannelRow` | Channel in any list |
| `SectionTitle` | Opens a group of rows, on every screen |
| `screenTitle` | Large title of a main screen, with an optional gray detail on the same line |
| `ExpandableText` | Long text in a box, collapsed to three lines |
| `MoreMenuLabel` | The "…" that opens a menu of secondary actions |
| `VideoControlButton` | Icon in a dark circle, readable on top of any video |
| `ToastView` | Short confirmation over the content |
| `CategoryMenu` | Picks a followed channel's category |

## Interaction rules

- One primary action per row: tapping a video plays it. Everything else is in its "…" menu, which long press also opens.
- Empty, loading and error states use `ContentUnavailableView` and `ProgressView`.
- Destructive actions use the `.destructive` role, and are always reachable by swipe or menu, never as a standing button.
- Only animate transform and opacity during the player transition, so it never triggers layout.
