DMXSmartLink Stream Deck remote apps (shipped with the hub, offered on Settings -> Stream Deck).
  DMXSmartLink-StreamDeck-Windows.zip  - Windows 10/11 x64 (windowed exe + hidapi.dll + README)
  DMXSmartLink-StreamDeck-macOS.zip    - macOS, Apple silicon ("DMXSmartLink Stream Deck.app", signed + notarized, + README)
Built by V36/platform/windows/build_streamdeck_remote.ps1 and V36/platform/macos/build_streamdeck_remote.sh.
The zips are build artifacts (not tracked in git); the hub serves them from this folder at
/api/control/remote-app/<windows|macos>, falling back to the GitHub release asset when absent.
