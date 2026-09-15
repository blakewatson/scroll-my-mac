import Cocoa

// Standalone regression checks: captures posted events; never creates a tap or
// posts global input. Compile with ScrollEngine, InertiaAnimator, VelocityTracker.
@main
struct ScrollEngineEventChecks {
    static func mouse(_ type: CGEventType, x: CGFloat = 100, number: Int64 = 42) -> CGEvent {
        let event = CGEvent(mouseEventSource: nil, mouseType: type,
                            mouseCursorPosition: CGPoint(x: x, y: 100), mouseButton: .left)!
        event.setIntegerValueField(.mouseEventNumber, value: number)
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        return event
    }

    static func waitForHold() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
    }

    static func main() {
        var posted: [(CGEvent, CGEventTapLocation)] = []
        let engine = ScrollEngine { posted.append(($0, $1)) }
        engine.holdToPassthroughEnabled = true
        engine.holdToPassthroughDelay = 0.01
        engine.isInertiaEnabled = false

        // Delayed down, drag, and up have matching identity and retain movement.
        assert(engine.handleMouseDown(event: mouse(.leftMouseDown)) == nil)
        waitForHold()
        assert(posted.map { $0.0.type } == [.leftMouseDown])
        let drag = mouse(.leftMouseDragged, x: 140, number: 99)
        drag.setIntegerValueField(.mouseEventDeltaX, value: 40)
        assert(engine.handleMouseDragged(event: drag) == nil)
        assert(engine.handleMouseUp(event: mouse(.leftMouseUp, x: 140, number: 99)) == nil)
        assert(posted.map { $0.0.type } == [.leftMouseDown, .leftMouseDragged, .leftMouseUp])
        assert(posted.allSatisfy { $0.1 == .cghidEventTap && $0.0.getIntegerValueField(.mouseEventNumber) == 42 })
        assert(posted[1].0.getIntegerValueField(.mouseEventDeltaX) == 40)
        assert(posted[2].0.location.x == 140)
        // Re-entering the tap with replay events cannot recursively replay them.
        assert(engine.handleMouseDown(event: posted[0].0) != nil)
        assert(engine.handleMouseDragged(event: posted[1].0) != nil)
        assert(engine.handleMouseUp(event: posted[2].0) != nil)
        assert(posted.count == 3)

        // A quick click produces exactly a pair, with no late timer down.
        posted.removeAll()
        _ = engine.handleMouseDown(event: mouse(.leftMouseDown))
        _ = engine.handleMouseUp(event: mouse(.leftMouseUp))
        waitForHold()
        assert(posted.map { $0.0.type } == [.leftMouseDown, .leftMouseUp])

        // Stopping before the deadline cannot replay a stale click.
        posted.removeAll()
        _ = engine.handleMouseDown(event: mouse(.leftMouseDown))
        engine.stop()
        waitForHold()
        assert(posted.isEmpty)

        // Stopping during passthrough releases the replayed button once.
        _ = engine.handleMouseDown(event: mouse(.leftMouseDown))
        waitForHold()
        _ = engine.handleMouseDragged(event: mouse(.leftMouseDragged, x: 170))
        engine.stop()
        engine.tearDown()
        assert(posted.map { $0.0.type } == [.leftMouseDown, .leftMouseDragged, .leftMouseUp])
        assert(posted.last!.0.location.x == 170)
        assert(engine.handleMouseUp(event: mouse(.leftMouseUp)) != nil)

        // Crossing the threshold cancels the hold and keeps scroll begin/end.
        posted.removeAll()
        _ = engine.handleMouseDown(event: mouse(.leftMouseDown))
        _ = engine.handleMouseDragged(event: mouse(.leftMouseDragged, x: 120))
        waitForHold()
        _ = engine.handleMouseUp(event: mouse(.leftMouseUp, x: 120))
        assert(posted.allSatisfy { $0.0.type == .scrollWheel })
        assert(posted.first!.0.getIntegerValueField(.scrollWheelEventScrollPhase) == 1)
        assert(posted.contains { $0.0.getIntegerValueField(.scrollWheelEventScrollPhase) == 4 })

        // Exclusion belongs to the whole gesture even when foreground changes.
        posted.removeAll()
        var excluded = true
        engine.shouldBypassAllEvents = { excluded }
        assert(engine.handleMouseDown(event: mouse(.leftMouseDown)) != nil)
        excluded = false
        assert(engine.handleMouseDragged(event: mouse(.leftMouseDragged)) != nil)
        assert(engine.handleMouseUp(event: mouse(.leftMouseUp)) != nil)
        waitForHold()
        assert(posted.isEmpty)
        _ = engine.handleMouseDown(event: mouse(.leftMouseDown))
        excluded = true
        waitForHold()
        _ = engine.handleMouseUp(event: mouse(.leftMouseUp))
        assert(posted.map { $0.0.type } == [.leftMouseDown, .leftMouseUp])
        engine.shouldBypassAllEvents = nil

        // Modifier clicks retain an ordinary down/drag/up sequence.
        posted.removeAll()
        let modified = mouse(.leftMouseDown)
        modified.flags = .maskShift
        assert(engine.handleMouseDown(event: modified) != nil)
        assert(engine.handleMouseDragged(event: mouse(.leftMouseDragged)) != nil)
        assert(engine.handleMouseUp(event: mouse(.leftMouseUp)) != nil)
        waitForHold()
        assert(posted.isEmpty)
        print("PASS: delayed drag identity, replay bypass, quick click, canceled hold, stop release, scroll threshold, exclusions, modifier passthrough")
    }
}
