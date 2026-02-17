# Scroll My Mac

A macOS accessibility app that lets you scroll anywhere by clicking and dragging.

## Vibe code alert

This app was built 100% with [Claude](https://claude.ai), Anthropic's AI assistant, and [GSD](https://github.com/gsd-build/get-shit-done). I don't know Swift. I wouldn't have made this app without AI, but it's something I wish existed. Use at your own risk.

## What It Does

Scroll My Mac adds system-wide click-and-drag scrolling to macOS. Toggle scroll mode with a hotkey, then click and drag to scroll any scrollable area on your screen.

- **System-wide scroll mode** -- activated via configurable hotkey (default: F6)
- **Natural inertia** -- momentum scrolling with smooth deceleration when you release the drag, like iOS or a trackpad
- **Click safety** -- small movements (~8px) pass through as normal clicks, so you won't accidentally scroll when you meant to click
- **Accessibility Keyboard aware** -- clicks on the macOS on-screen keyboard always pass through instantly, even while scroll mode is active
- **Customizable hotkey** -- change the toggle key to any key or modifier combo
- **Launch at login** -- optional automatic startup

## Why It Exists

This app was built for users who cannot use a trackpad or scroll wheel due to disability. I rely on an [on-screen keyboard](https://blakewatson.com/journal/writing-and-coding-with-the-macos-accessibility-keyboard/) and mouse for input, and needed a way to [scroll without a scroll wheel](https://blakewatson.com/journal/neglecting-the-scrollbar-a-costly-trend-in-ui-design/) or trackpad gesture.

It was inspired by the [ScrollAnywhere](https://fastaddons.com/#scroll_anywhere) browser extension, which provides click-and-drag scrolling in the browser. Scroll My Mac brings similar (albeit less customizable) capability to operating system level.

## Installation

1. Download `ScrollMyMac.zip` from the [latest GitHub release](https://github.com/blakewatson/scroll-my-mac/releases/latest)
2. Extract the zip
3. Move `ScrollMyMac.app` to `/Applications`
4. Launch the app and grant Accessibility permission when prompted

## Usage

1. Press **F6** (or your configured hotkey) to toggle scroll mode on
2. Click and drag to scroll (vertically or horizontally)
3. Release to let inertia carry the scroll naturally
4. Small clicks pass through as normal clicks (turn this off in settings if you don’t want this behavior)
5. Press the hotkey again to toggle scroll mode off

The app window provides settings for hotkey customization and launch at login.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon Macs only (if there is sufficient interest, I can try a universal build)
- Accessibility permission (the app will guide you through granting it on first launch)

## Roadmap

- An optional visual indicator to communicate whether scroll mode is activated.

## License

This project is licensed under the [MIT License](LICENSE).
