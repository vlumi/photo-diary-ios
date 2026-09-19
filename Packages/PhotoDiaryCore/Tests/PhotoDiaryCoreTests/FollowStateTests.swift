import Foundation
import Testing

@testable import PhotoDiaryCore

struct FollowStateTests {
    @Test func offNeverRecenters() {
        let follow = FollowState()
        #expect(!follow.isOn)
        #expect(!follow.isDue())
    }

    @Test func firstFixAfterStartIsDueThenThrottled() {
        var follow = FollowState()
        follow.start()
        let t0 = Date()
        #expect(follow.isDue(at: t0))
        follow.recentered(at: t0)
        #expect(!follow.isDue(at: t0.addingTimeInterval(3)))
        #expect(follow.isDue(at: t0.addingTimeInterval(FollowState.interval)))
    }

    @Test func stopForgetsTheClock() {
        var follow = FollowState()
        follow.start()
        follow.recentered()
        follow.stop()
        #expect(!follow.isOn)
        follow.start()
        #expect(follow.isDue(), "switching back on re-centers at once")
    }

    @Test(arguments: [80.0, 300, 1_200, 3_000])
    func locatingKeepsAZoomThatAlreadyShowsTheSurroundings(current: Double) {
        #expect(FollowState.locateMeters(current: current, closeUp: 300) == current)
    }

    @Test(arguments: [3_100.0, 2_000_000])
    func locatingFromFarOutZoomsInToTheCloseUp(current: Double) {
        #expect(FollowState.locateMeters(current: current, closeUp: 300) == 300)
    }
}
