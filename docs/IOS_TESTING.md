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
- [ ] right joystick aims continuously and fires once when entering its outer ring
- [ ] holding the right joystick at the edge does not spam attacks; returning inward and pushing outward fires again
- [ ] simultaneous move + aim
- [ ] controls stay inside the safe area on 16:9, 19.5:9/notched and 4:3 landscape screens
- [ ] attack
- [ ] interact
- [ ] interaction prompt identifies the nearest item or container
- [ ] container panel opens without automatically taking an item
- [ ] explicit container take and backpack deposit update only after server confirmation
- [ ] empty container can be opened and accepts a deposit
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
