// iOS 27 SDK asserts at launch unless the app adopts the UIScene life cycle.
// Expo SDK 57 ships `ExpoAppSceneDelegate` but its template doesn't use it yet:
// this plugin wires it up (SceneDelegate.swift, AppDelegate changes, Info.plist manifest).
const fs = require("fs");
const path = require("path");
const {
	IOSConfig,
	withDangerousMod,
	withInfoPlist,
	withXcodeProject,
} = require("expo/config-plugins");

const SCENE_DELEGATE = `internal import Expo

@objc(SceneDelegate)
class SceneDelegate: ExpoAppSceneDelegate {
  // Extension point for config plugins.
}
`;

const withSceneDelegateFiles = (config) =>
	withDangerousMod(config, [
		"ios",
		(config) => {
			const projectName = IOSConfig.XcodeUtils.getProjectName(
				config.modRequest.projectRoot,
			);
			const dir = path.join(config.modRequest.platformProjectRoot, projectName);
			fs.writeFileSync(path.join(dir, "SceneDelegate.swift"), SCENE_DELEGATE);

			const appDelegatePath = path.join(dir, "AppDelegate.swift");
			let src = fs.readFileSync(appDelegatePath, "utf8");
			src = src.replace(
				/class AppDelegate: ExpoAppDelegate(?!, ExpoReactNativeFactoryProvider)/,
				"class AppDelegate: ExpoAppDelegate, ExpoReactNativeFactoryProvider",
			);
			// The window is created and React Native started by SceneDelegate.
			src = src.replace(
				/#if os\(iOS\) \|\| os\(tvOS\)\s*window = UIWindow\(frame: UIScreen\.main\.bounds\)[\s\S]*?#endif\n/,
				"",
			);
			fs.writeFileSync(appDelegatePath, src);
			return config;
		},
	]);

const withSceneDelegateXcode = (config) =>
	withXcodeProject(config, (config) => {
		const projectName = IOSConfig.XcodeUtils.getProjectName(
			config.modRequest.projectRoot,
		);
		const filepath = `${projectName}/SceneDelegate.swift`;
		if (!config.modResults.hasFile(filepath)) {
			IOSConfig.XcodeUtils.addBuildSourceFileToGroup({
				filepath,
				groupName: projectName,
				project: config.modResults,
			});
		}
		return config;
	});

const withSceneManifest = (config) =>
	withInfoPlist(config, (config) => {
		config.modResults.UIApplicationSceneManifest = {
			UIApplicationSupportsMultipleScenes: false,
			UISceneConfigurations: {
				UIWindowSceneSessionRoleApplication: [
					{
						UISceneConfigurationName: "Default Configuration",
						UISceneDelegateClassName: "$(PRODUCT_MODULE_NAME).SceneDelegate",
					},
				],
			},
		};
		return config;
	});

module.exports = (config) =>
	withSceneManifest(withSceneDelegateXcode(withSceneDelegateFiles(config)));
