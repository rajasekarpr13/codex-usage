# Codex Usage for macOS

A small macOS menu-bar app that shows the percentage of your Codex five-hour and weekly usage allowances remaining. Click the display to see reset times, refresh, or quit. Values update every five minutes.

The percentages are green above 30% remaining, orange at 11–30%, and red at 10% or less. If an update fails, the last successful values remain visible; open the menu to see the error and update time. A usage window that your account does not return is shown as unavailable.

## Requirements

- macOS and Xcode Command Line Tools (`xcode-select --install`)
- ChatGPT desktop app installed at `/Applications/ChatGPT.app`, with a ChatGPT account signed in and Codex usage limits available

The app uses the Codex CLI bundled with ChatGPT to read the signed-in account's rate limits. It does not need a separate API key. Availability of five-hour and weekly windows depends on your account and plan. The CLI path or server protocol may change in a future ChatGPT update.

## Install and run

In Terminal, clone this repository and build the app:

```sh
git clone https://github.com/rajasekarpr13/codex-usage.git
cd codex-usage
bash install.sh
open "build/Codex Usage.app"
```

The build is locally ad-hoc signed and is not notarized. If macOS blocks it, use Finder to open the app and follow the macOS security prompt. To keep it somewhere permanent, move `build/Codex Usage.app` to your Applications folder. To start it when you sign in, add it under **System Settings → General → Login Items**.

## How it works

The app starts the locally installed Codex app server and requests `account/rateLimits/read`; it shows remaining percentage as 100 minus the reported percentage used. It only requests usage information and does not change limits or consume reset credits. If the server is unavailable, check that ChatGPT is installed and signed in, then use **Refresh now** in the menu.

The app remains in the menu bar with no Dock icon. To uninstall it, quit it from its menu and delete the app; remove it from Login Items if you added it there.
