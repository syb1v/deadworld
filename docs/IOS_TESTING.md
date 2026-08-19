# iOS physical acceptance

CI produces `deadworld-ios-arm64-unsigned.ipa` for later resigning. CI build verification does not prove that a third-party certificate/profile is compatible or that the app works on a physical iPhone.

- [ ] IPA imported into GBox
- [ ] GBox signing succeeds
- [ ] IPA installs on iPhone
- [ ] app launches
- [ ] main menu visible
- [ ] production backend connects
- [ ] authentication succeeds
- [ ] player enters same world as PC
- [ ] touch movement
- [ ] simultaneous move + aim
- [ ] attack
- [ ] interact
- [ ] reload
- [ ] inventory slots
- [ ] drop
- [ ] pause
- [ ] collision
- [ ] zombies
- [ ] loot
- [ ] containers
- [ ] damage
- [ ] death
- [ ] respawn
- [ ] background -> foreground
- [ ] Wi-Fi loss -> reconnect
- [ ] persistence
- [ ] PC <-> iPhone crossplay

Do not mark items as passed without a physical iPhone test using the exact downloaded IPA and the owner's actual resigning profile.
