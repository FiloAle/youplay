import React, { useEffect } from "react";
import { StyleSheet, View } from "react-native";
import Animated, {
	useAnimatedStyle,
	useSharedValue,
	withSpring,
	withTiming,
	runOnJS,
} from "react-native-reanimated";
import { Host, HStack, Image as SwiftUIImage, Text as SwiftUIText } from "@expo/ui/swift-ui";
import { glassEffect, cornerRadius, font, tint, padding, frame } from "@expo/ui/swift-ui/modifiers";

interface ToastHUDProps {
	visible: boolean;
	message: string;
	onHide: () => void;
}

export default function ToastHUD({ visible, message, onHide }: ToastHUDProps) {
	const opacity = useSharedValue(0);
	const scale = useSharedValue(0.8);

	useEffect(() => {
		if (visible) {
			opacity.value = withTiming(1, { duration: 150 });
			scale.value = withTiming(1, { duration: 150 });

			const timeout = setTimeout(() => {
				opacity.value = withTiming(0, { duration: 200 });
				scale.value = withTiming(0.8, { duration: 200 }, (finished) => {
					if (finished) {
						runOnJS(onHide)();
					}
				});
			}, 2000);

			return () => clearTimeout(timeout);
		} else {
			opacity.value = withTiming(0, { duration: 200 });
			scale.value = withTiming(0.8, { duration: 200 });
		}
	}, [visible]);

	const animatedStyle = useAnimatedStyle(() => ({
		opacity: opacity.value,
		transform: [{ scale: scale.value }],
	}));

	// Non rendiamo nulla se l'opacità è 0 per motivi di performance (handled by pointerEvents="none" in parent)
	return (
		<View
			style={styles.overlay}
			pointerEvents="none"
		>
			<Animated.View style={animatedStyle}>
				<Host style={styles.hudContainer}>
					<HStack
						spacing={8}
						modifiers={[
							frame({ width: 200, height: 48 }),
							glassEffect({
								glass: { variant: "regular" },
								shape: "capsule",
							}),
						]}
					>
						<SwiftUIImage
							systemName="checkmark.circle.fill"
							modifiers={[
								font({ size: 16, weight: "medium" }),
								tint("#FFF"),
							]}
						/>
						<SwiftUIText
							modifiers={[
								font({ size: 15, weight: "semibold" }),
								tint("#FFF"),
							]}
						>
							{message}
						</SwiftUIText>
					</HStack>
				</Host>
			</Animated.View>
		</View>
	);
}

const styles = StyleSheet.create({
	overlay: {
		...StyleSheet.absoluteFill,
		justifyContent: "flex-end",
		alignItems: "center",
		paddingBottom: 170,
		zIndex: 9999,
		elevation: 9999,
	},
	hudContainer: {
		width: 200,
		height: 48,
	},
});
