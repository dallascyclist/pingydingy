import Testing
import Foundation
@testable import PingyDingy

@Test func soundManagerInitialState() {
    let manager = SoundManager()
    #expect(manager.masterSoundEnabled == true)
}

@Test func soundManagerMasterToggle() {
    let manager = SoundManager()
    manager.masterSoundEnabled = false
    #expect(manager.masterSoundEnabled == false)
}

@Test func soundManagerTransitionCooldown() {
    let manager = SoundManager()
    let hostId = UUID()

    manager.playTransitionSound(hostId: hostId, wentUp: true)
    manager.playTransitionSound(hostId: hostId, wentUp: false)

    let hostId2 = UUID()
    manager.playTransitionSound(hostId: hostId2, wentUp: true)
}

@Test func soundManagerPerPingSoundRespectsFlags() {
    let manager = SoundManager()

    manager.playPingSound(success: true, hostSoundEnabled: true)
    manager.playPingSound(success: false, hostSoundEnabled: true)
    manager.playPingSound(success: true, hostSoundEnabled: false)

    manager.masterSoundEnabled = false
    manager.playPingSound(success: true, hostSoundEnabled: true)
}
