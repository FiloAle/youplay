import { usePlayerActions, usePlayerState } from "@/contexts/PlayerContext";
import { Menu, Picker, Text } from "@expo/ui/swift-ui";
import { pickerStyle, tag } from "@expo/ui/swift-ui/modifiers";
import { glassIconButton } from "./glass-icon-button";

const QUALITY_OPTIONS = [
	{ height: 0, label: "Automatica" },
	{ height: 1080, label: "1080p" },
	{ height: 720, label: "720p" },
	{ height: 480, label: "480p" },
	{ height: 360, label: "360p" },
];

/** Must be rendered inside a SwiftUI `Host`. */
export default function QualityMenu() {
	const { maxQuality } = usePlayerState();
	const { setMaxQuality } = usePlayerActions();

	return (
		<Menu label="Qualità" systemImage="slider.horizontal.3" modifiers={glassIconButton}>
			<Picker
				label="Qualità massima"
				selection={maxQuality}
				onSelectionChange={setMaxQuality}
				modifiers={[pickerStyle("inline")]}
			>
				{QUALITY_OPTIONS.map((q) => (
					<Text key={q.height} modifiers={[tag(q.height)]}>
						{q.label}
					</Text>
				))}
			</Picker>
		</Menu>
	);
}
