//
//  MailbagScene.swift
//  PomoPenpal
//
//  SpriteKit scene that renders the weekly letter-pile (Decision #13).
//  Letters drop in as thin cream rectangles, settle under gravity, react to
//  window drag, and can be plucked with click-and-hold. The all-time peak
//  pile height is preserved as a faint chalk-mark on the back wall.
//
//  Each letter's physics body is taller than its visible sprite by
//  `verticalBodyPadding` so the pile settles with visible gaps between
//  stacked letters (matches the "padding between letters" design fix).
//

import AppKit
import SpriteKit

final class MailbagScene: SKScene {

    // Visual constants — tune by feel (Decision #13, album-layout-ideas.md "Open questions").
    private let letterSize = CGSize(width: 140, height: 8)
    /// Extra height added to each letter's physics body (split evenly above/below
    /// the visible sprite) so stacked letters settle with a visible gap.
    private let verticalBodyPadding: CGFloat = 4

    // Use explicit sRGB so SpriteKit's Metal-backed pipeline doesn't pick up an
    // unexpected color space (which on macOS can wash cream into off-white).
    private let backWallColor    = NSColor(srgbRed: 0.860, green: 0.795, blue: 0.685, alpha: 1.0) // ~#DBCBAF — clearly darker than letter cream
    private let letterFillColor  = NSColor(srgbRed: 0.969, green: 0.914, blue: 0.851, alpha: 1.0) // #F7E9D9
    private let letterStrokeColor = NSColor(srgbRed: 0.687, green: 0.601, blue: 0.479, alpha: 1.0) // ~#AF997A — soft taupe edge
    private let chalkColor       = NSColor(srgbRed: 0.878, green: 0.815, blue: 0.713, alpha: 1.0) // ~#E0D0B6

    // Physics tuning
    private let gravityY: CGFloat = -4.5  // gentler than default so the fall reads as a settle, not a streak
    private let letterDensity: CGFloat = 1.2
    private let letterRestitution: CGFloat = 0.05  // letters thud, no bounce
    private let letterFriction: CGFloat = 0.7
    private let letterLinearDamping: CGFloat = 0.5
    private let letterAngularDamping: CGFloat = 0.7

    // Overflow: when the pile crosses ~75% window height, oldest letters merge
    // into a single static block at the bottom so the user-visible pile never
    // clips the top of the 240pt window.
    private let overflowFraction: CGFloat = 0.75

    // UserDefaults key for the all-time best pile height (in scene-pt).
    private let bestHeightKey = "MailbagScene.bestPileHeight"

    // Tracked nodes — oldest first, so we can compact from the front.
    // Stored as SKNode so the array can hold either SKShapeNode letters or
    // future representations without churn.
    private var letterOrder: [SKNode] = []
    private var compactedBlock: SKSpriteNode?
    private var compactedDivider: SKShapeNode?
    private var chalkMark: SKShapeNode?

    // Pluck/drag state.
    private var dragAnchor: SKNode?
    private var dragJoint: SKPhysicsJoint?

    // Cached peak-height (pixels) for the chalk-mark.
    private var bestPileHeight: CGFloat = 0

    // External hook for "letters changed; update count readout" — set by AlbumView.
    var onCountsChanged: (() -> Void)?

    /// Effective vertical footprint of one stacked letter, including the body padding.
    var effectiveLetterHeight: CGFloat { letterSize.height + verticalBodyPadding }

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
        // Static block that grows as oldest letters merge in.
        let block = SKSpriteNode(color: letterFillColor, size: CGSize(width: size.width, height: 0))
        block.anchorPoint = CGPoint(x: 0.5, y: 0)
        block.position = CGPoint(x: size.width / 2, y: 0)
        block.zPosition = -0.5
        addChild(block)
        compactedBlock = block

        // Hairline divider on top so the block reads as compacted letters and
        // not as one solid extension of the active pile above.
        let divider = SKShapeNode()
        divider.strokeColor = letterStrokeColor
        divider.lineWidth = 1.0
        divider.alpha = 0.85
        divider.zPosition = -0.4
        divider.isHidden = true
        addChild(divider)
        compactedDivider = divider
    }

    private func updateCompactedDivider() {
        guard let block = compactedBlock, let divider = compactedDivider else { return }
        if block.size.height <= 0.5 {
            divider.isHidden = true
            return
        }
        let topY = block.size.height
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 4, y: topY))
        path.addLine(to: CGPoint(x: size.width - 4, y: topY))
        divider.path = path
        divider.isHidden = false
    }

    // MARK: - Adding letters

    /// Repopulate the scene. `seen` letters appear at rest at the bottom (no
    /// fall animation — the user already watched these drop on a prior open).
    /// `new` letters drop in from above with a staggered fall.
    ///
    /// If the count of `seen` letters alone would overflow the visible heap,
    /// the oldest are merged into the static compacted block up front so the
    /// runtime overflow detector doesn't have to chew through them one frame
    /// at a time post-open.
    func reload(seen: [Letter], new: [Letter]) {
        letterOrder.forEach { $0.removeFromParent() }
        letterOrder.removeAll()
        if let block = compactedBlock { block.size.height = 0 }

        let sortedSeen = seen.sorted { $0.dateEarned < $1.dateEarned }
        let sortedNew = new.sorted { $0.dateEarned < $1.dateEarned }

        // Pre-compact: any seen letters that wouldn't fit fold into the block.
        let visibleCap = max(0, Int(size.height * overflowFraction / max(effectiveLetterHeight, 1)))
        let preCompactCount = max(0, sortedSeen.count - visibleCap)
        if preCompactCount > 0, let block = compactedBlock {
            block.size = CGSize(width: size.width,
                                height: CGFloat(preCompactCount) * letterSize.height)
        }
        updateCompactedDivider()

        let visibleSeen = Array(sortedSeen.dropFirst(preCompactCount))
        let baseY = (compactedBlock?.size.height ?? 0) + effectiveLetterHeight / 2

        // Place visible seen at calculated stack positions with a small x-jitter.
        for (i, _) in visibleSeen.enumerated() {
            let y = baseY + CGFloat(i) * effectiveLetterHeight
            let xJitter = CGFloat.random(in: -18...18)
            spawnLetterSprite(
                at: CGPoint(x: clampedX(size.width / 2 + xJitter), y: y),
                rotation: CGFloat.random(in: -0.04...0.04)
            )
        }

        // Drop new letters with stagger so they pile rather than co-spawn.
        for (i, _) in sortedNew.enumerated() {
            let delay = SKAction.wait(forDuration: Double(i) * 0.06)
            let spawn = SKAction.run { [weak self] in
                guard let self else { return }
                let xJitter = CGFloat.random(in: -26...26)
                self.spawnLetterSprite(
                    at: CGPoint(x: self.clampedX(self.size.width / 2 + xJitter),
                                y: self.size.height + 24),
                    rotation: CGFloat.random(in: -0.09...0.09)
                )
            }
            run(SKAction.sequence([delay, spawn]))
        }

        onCountsChanged?()
    }

    /// Drop a single new letter into a live scene (mid-session work-end).
    func dropOneLetter() {
        let xJitter = CGFloat.random(in: -26...26)
        spawnLetterSprite(
            at: CGPoint(x: clampedX(size.width / 2 + xJitter), y: size.height + 24),
            rotation: CGFloat.random(in: -0.09...0.09)
        )
        onCountsChanged?()
    }

    private func spawnLetterSprite(at position: CGPoint, rotation: CGFloat) {
        // SKShapeNode rather than SKSpriteNode so each letter has a hairline
        // taupe stroke around its cream fill — gives every letter a visible
        // edge regardless of how subtly the back-wall color differs from cream.
        let node = SKShapeNode(rectOf: letterSize)
        node.fillColor = letterFillColor
        node.strokeColor = letterStrokeColor
        node.lineWidth = 1.0
        node.position = position
        node.zRotation = rotation
        node.zPosition = 1

        // Body is taller than the sprite so stacked letters settle with a visible gap.
        let bodySize = CGSize(width: letterSize.width,
                              height: letterSize.height + verticalBodyPadding)
        let body = SKPhysicsBody(rectangleOf: bodySize)
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

    private func clampedX(_ x: CGFloat) -> CGFloat {
        let halfW = letterSize.width / 2
        return max(halfW + 2, min(size.width - halfW - 2, x))
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
        // Letters are SKShapeNodes (not SKSpriteNodes) — match against the
        // tracked node array by reference identity rather than casting.
        let hits = nodes(at: p)
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
        updateCompactedDivider()
        onCountsChanged?()
    }
}
