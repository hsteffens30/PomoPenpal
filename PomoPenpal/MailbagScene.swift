//
//  MailbagScene.swift
//  PomoPenpal
//
//  SpriteKit scene that renders the weekly letter-pile (Decision #13).
//  Letters drop in as thin cream rectangles, settle under gravity, react to
//  window drag, and can be plucked with click-and-hold. The all-time peak
//  pile height is preserved as a faint chalk-mark on the back wall.
//

import AppKit
import SpriteKit

final class MailbagScene: SKScene {

    // Visual constants — tune by feel (Decision #13, album-layout-ideas.md "Open questions").
    private let letterSize = CGSize(width: 80, height: 3)
    private let chalkColor = NSColor(hex: 0xE0D0B6)
    private let backWallColor = NSColor(hex: 0xEDDCC5)  // a touch darker than cream

    // Physics tuning
    private let gravityY: CGFloat = -8.0
    private let letterDensity: CGFloat = 1.2
    private let letterRestitution: CGFloat = 0.05  // letters thud, no bounce
    private let letterFriction: CGFloat = 0.7
    private let letterLinearDamping: CGFloat = 0.3
    private let letterAngularDamping: CGFloat = 0.6

    // Overflow: when the pile crosses ~75% window height, oldest letters merge
    // into a single static block at the bottom so the user-visible pile never
    // clips the top of the 240pt window.
    private let overflowFraction: CGFloat = 0.75

    // UserDefaults key for the all-time best pile height (in scene-pt).
    private let bestHeightKey = "MailbagScene.bestPileHeight"

    // Tracked nodes — oldest first, so we can compact from the front.
    private var letterOrder: [SKSpriteNode] = []
    private var compactedBlock: SKSpriteNode?
    private var chalkMark: SKShapeNode?

    // Pluck/drag state.
    private var dragAnchor: SKNode?
    private var dragJoint: SKPhysicsJoint?

    // Cached peak-height (pixels) for the chalk-mark.
    private var bestPileHeight: CGFloat = 0

    // External hook for "letters changed; update count readout" — set by AlbumView.
    var onCountsChanged: (() -> Void)?

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = backWallColor
        // .resizeFill makes the scene's logical size match the SpriteView pixel size 1:1.
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: gravityY)
        physicsWorld.speed = 1.0

        bestPileHeight = CGFloat(UserDefaults.standard.double(forKey: bestHeightKey))

        rebuildWalls()
        installChalkMark()
        installCompactedBlock()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size != .zero else { return }
        rebuildWalls()
        chalkMark?.path = chalkPath()
        if let block = compactedBlock {
            block.position.x = size.width / 2
        }
    }

    // MARK: - Scene chrome

    private func rebuildWalls() {
        // Edge loop on left, bottom, right; top is open so letters drop in.
        let extra: CGFloat = 400  // extend walls above the visible area for free-fall
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size.height + extra))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: size.height + extra))
        let wallBody = SKPhysicsBody(edgeChainFrom: path)
        wallBody.friction = 0.9
        wallBody.restitution = 0.05
        physicsBody = wallBody
    }

    private func installChalkMark() {
        let mark = SKShapeNode()
        mark.path = chalkPath()
        mark.strokeColor = chalkColor
        mark.lineWidth = 0.6
        mark.alpha = 0.7
        mark.zPosition = -1
        chalkMark = mark
        addChild(mark)
        updateChalkMarkPosition()
    }

    private func chalkPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 6, y: 0))
        p.addLine(to: CGPoint(x: size.width - 6, y: 0))
        return p
    }

    private func updateChalkMarkPosition() {
        chalkMark?.position = CGPoint(x: 0, y: bestPileHeight)
        chalkMark?.isHidden = bestPileHeight < 6
    }

    private func installCompactedBlock() {
        // Hairline divider + static block that grows as oldest letters merge in.
        let block = SKSpriteNode(color: Palette.creamNS, size: CGSize(width: size.width, height: 0))
        block.anchorPoint = CGPoint(x: 0.5, y: 0)
        block.position = CGPoint(x: size.width / 2, y: 0)
        block.zPosition = -0.5
        addChild(block)
        compactedBlock = block
    }

    // MARK: - Adding letters

    /// Clear and repopulate the scene with the given letters (Sorted oldest → newest).
    /// Drops happen staggered so the pile builds up visibly instead of in a single thud.
    func reload(with letters: [Letter]) {
        letterOrder.forEach { $0.removeFromParent() }
        letterOrder.removeAll()
        if let block = compactedBlock {
            block.size.height = 0
        }

        let sorted = letters.sorted { $0.dateEarned < $1.dateEarned }
        for (i, letter) in sorted.enumerated() {
            let delay = SKAction.wait(forDuration: Double(i) * 0.04)
            let spawn = SKAction.run { [weak self, letter] in
                self?.spawnLetterSprite(seed: letter.id.uuidString.hashValue)
            }
            run(SKAction.sequence([delay, spawn]))
        }
        onCountsChanged?()
    }

    /// Drop a single new letter into a live scene (mid-session work-end).
    func dropOneLetter() {
        spawnLetterSprite(seed: Int(Date().timeIntervalSinceReferenceDate * 1000))
        onCountsChanged?()
    }

    private func spawnLetterSprite(seed: Int) {
        var rng = SeededRandom(seed: UInt64(bitPattern: Int64(seed)))
        let xJitter = CGFloat(rng.next(in: -30...30))
        let rotJitter = CGFloat(rng.next(in: -0.09...0.09))  // ±~5°

        let node = SKSpriteNode(color: Palette.creamNS, size: letterSize)
        node.position = CGPoint(x: max(letterSize.width, size.width / 2 + xJitter),
                                y: size.height + 20)
        node.zRotation = rotJitter
        node.zPosition = 1

        let body = SKPhysicsBody(rectangleOf: letterSize)
        body.density = letterDensity
        body.restitution = letterRestitution
        body.friction = letterFriction
        body.linearDamping = letterLinearDamping
        body.angularDamping = letterAngularDamping
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = false
        node.physicsBody = body

        addChild(node)
        letterOrder.append(node)
    }

    // MARK: - Window drag impulse

    /// Convert a window-move delta into an impulse on every dynamic letter so the
    /// pile leans and resettles in the opposite direction (inertia).
    func applyWindowMoveImpulse(dx: CGFloat, dy: CGFloat) {
        let impulse = CGVector(dx: -dx * 0.35, dy: -dy * 0.35)
        for node in letterOrder {
            node.physicsBody?.applyImpulse(impulse)
        }
    }

    // MARK: - Pluck-and-hold

    override func mouseDown(with event: NSEvent) {
        let p = event.location(in: self)
        let hits = nodes(at: p).compactMap { $0 as? SKSpriteNode }
        guard let target = hits.first(where: { letterOrder.contains($0) }),
              let body = target.physicsBody else { return }

        let anchor = SKNode()
        anchor.position = p
        let anchorBody = SKPhysicsBody(circleOfRadius: 0.5)
        anchorBody.isDynamic = false
        anchor.physicsBody = anchorBody
        addChild(anchor)

        let joint = SKPhysicsJointSpring.joint(withBodyA: body,
                                               bodyB: anchorBody,
                                               anchorA: p,
                                               anchorB: p)
        joint.frequency = 14
        joint.damping = 3
        physicsWorld.add(joint)

        dragAnchor = anchor
        dragJoint = joint
    }

    override func mouseDragged(with event: NSEvent) {
        dragAnchor?.position = event.location(in: self)
    }

    override func mouseUp(with event: NSEvent) {
        releaseDrag()
    }

    private func releaseDrag() {
        if let joint = dragJoint {
            physicsWorld.remove(joint)
            dragJoint = nil
        }
        dragAnchor?.removeFromParent()
        dragAnchor = nil
    }

    // MARK: - Per-frame work

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        // Early-out on empty pile — avoid per-frame O(N) work and any
        // possible empty-scene render pathology while idle.
        guard !letterOrder.isEmpty, size.height > 0 else { return }

        // Update peak-height chalk-mark.
        var topY: CGFloat = 0
        for n in letterOrder where n.position.y > topY { topY = n.position.y }

        if topY > bestPileHeight {
            bestPileHeight = topY
            UserDefaults.standard.set(Double(topY), forKey: bestHeightKey)
            updateChalkMarkPosition()
        }

        // Overflow: oldest letters merge into the static compacted block at the bottom.
        if topY > size.height * overflowFraction {
            compactOldestLetter()
        }
    }

    private func compactOldestLetter() {
        guard letterOrder.count > 1, let oldest = letterOrder.first else { return }
        oldest.removeFromParent()
        letterOrder.removeFirst()

        if let block = compactedBlock {
            block.size = CGSize(width: size.width, height: block.size.height + letterSize.height)
        }
        onCountsChanged?()
    }
}

// MARK: - Seeded RNG for visible-jitter reproducibility per letter ID

private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEF : seed }

    mutating func nextRaw() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let r = Double(nextRaw() % 1_000_000) / 1_000_000
        return range.lowerBound + r * (range.upperBound - range.lowerBound)
    }
}
