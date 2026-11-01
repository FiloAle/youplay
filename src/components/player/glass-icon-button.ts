import {
	font,
	frame,
	glassEffect,
	labelStyle,
	tint,
} from "@expo/ui/swift-ui/modifiers";

/** Modifiers for the round glass icon buttons used across the player. */
export const glassIconButton = [
	labelStyle("iconOnly"),
	font({ size: 16, weight: "semibold" }),
	tint("#FFF"),
	frame({ width: 36, height: 36 }),
	glassEffect({
		glass: { variant: "regular", interactive: true },
		shape: "ellipse",
	}),
];
