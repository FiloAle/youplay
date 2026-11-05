Native iOS app in SwiftUI. Structure is in README.md; design rules are in DESIGN.md.

Every time you edit code, make sure it compiles with `xcodebuild -project YouPlay.xcodeproj -scheme YouPlay -destination 'generic/platform=iOS Simulator' build`.

NEVER run the app on a simulator or device, just tell the user when it's time to.

Always think if there's a better and cleaner way to do things, think like a senior software engineer.

Try to componentize code as much as possible to make it more readable and reusable. However, if a component is only used once, it's fine to not componentize it.

Never waste tokens to reply with long explanations. Be VERY concise and straight to the point.
