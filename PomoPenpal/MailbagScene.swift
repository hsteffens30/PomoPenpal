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
    private let letterFriction: CGFloat = 0.85
    private let letterLinearDamping: CGFloat = 0.85    // higher so window-drag slosh dies out quickly
    private let letterAngularDamping: CGFloat = 0.9    // higher so letters barely tumble when jostled

    // How strongly window-drag deltas translate into impulses on the heap.
    // Lower = subtler, slower-feeling reaction; raise toward 1.0 for a more
    // dramatic slosh.
    private let windowImpulseScale: CGFloat = 0.10

    // Layout: stack letters in N side-by-side columns. With 140pt letters on a
    // 360pt window, 2 columns is the natural max (3 would need 420pt). Per-
    // column cap × column count is the visible cap; anything beyond folds into
    // the compacted block.
    private let columnCount: Int = 2
    private let columnGap: CGFloat = 20
    private let maxLettersPerColumn: Int = 13
    private var maxVisibleLetters: Int { columnCount * maxLettersPerColumn }

    // Compacted block: grows half as fast per merged letter as a stacked letter
    // would, capped at maxBlockHeight so heavy weeks stay visually contained.
    private let blockHeightPerLetter: CGFloat = 4
    private let maxBlockHeight: CGFloat = 80

    // UserDefaults key for the all-time best pile height (in scene-pt).
    private let bestHeightKey = "MailbagScene.bestPileHeight"

    // Tracked nodes — oldest first, so we can compact from the front.
    // Stored as SKNode so the array can hold either SKShapeNode letters or
    // future representations without churn.
    private var letterOrder: [SKNode] = []
    private var compactedBlock: SKSpriteNode?
    private var compactedDivider: SKShapeNode?
    private var chalkMark: SKShapeNode?

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
        // Defensive: an earlier version could store off-screen values when a
        // mid-air letter's transient y was counted. If the stored peak is
        // above the visible area, treat it as corrupt and reset so future
        // legitimate piles can register a new best.
        if size.height > 0, bestPileHeight > size.height {
            bestPileHeight = 0
            UserDefaults.standard.set(0, forKey: bestHeightKey)
        }

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
            // Width may have changed — rebuild the block's physics body.
            updateBlockPhysics()
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

    /// Build a static physics body matching the current block visual so dynamic
    /// letters land on top of the block rather than falling through it to the
    /// floor. Called every time block.size changes.
    private func updateBlockPhysics() {
        guard let block = compactedBlock else { return }
        if block.size.height < 0.5 {
            block.physicsBody = nil
            return
        }
        // Block has anchor (0.5, 0) so its local origin is the bottom-center.
        // The body must be centered at (0, height/2) to align with the visual.
        let body = SKPhysicsBody(
            rectangleOf: block.size,
            center: CGPoint(x: 0, y: block.size.height / 2)
        )
        body.isDynamic = false
        body.friction = 0.9
        body.restitution = 0.05
        block.physicsBody = body
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

    /// Repopulate the scene. `seen` letters appear at rest above the compacted
    /// block (no fall animation — the user already watched these drop on a prior
    /// open). `new` letters drop in from above with a staggered fall.
    ///
    /// Layout strategy: cap visible individual letters at `maxVisibleLetters`
    /// (columnCount × maxLettersPerColumn) so the pile never spawns letters
    /// above the visible window. Anything beyond the cap folds into the
    /// compacted block. Visible letters distribute round-robin across columns
    /// so both piles grow in parallel rather than filling one before the next.
    func reload(seen: [Letter], new: [Letter]) {
        letterOrder.forEach { $0.removeFromParent() }
        letterOrder.removeAll()
        if let block = compactedBlock { block.size.height = 0 }

        let sortedSeen = seen.sorted { $0.dateEarned < $1.dateEarned }
        let sortedNew = new.sorted { $0.dateEarned < $1.dateEarned }

        // Carve out room for new letters first (they're the focus). The rest
        // of the visible budget goes to recent seen letters; older seen ones
        // fold into the compacted block.
        let visibleSeenCount = max(0, min(maxVisibleLetters - sortedNew.count, sortedSeen.count))
        let compactedCount = sortedSeen.count - visibleSeenCount
        let blockHeight = min(maxBlockHeight, CGFloat(compactedCount) * blockHeightPerLetter)
        if let block = compactedBlock {
            block.size = CGSize(width: size.width, height: blockHeight)
        }
        updateBlockPhysics()
        updateCompactedDivider()

        // visibleSeen = the most-recent N seen letters (oldest go into block).
        let visibleSeen = Array(sortedSeen.suffix(visibleSeenCount))
        // 2pt margin above the block top so dynamic bodies don't intersect the
        // newly-installed static block body and get shoved.
        let baseY = blockHeight + effectiveLetterHeight / 2 + 2

        // Distribute visible-seen across columns round-robin so both stacks
        // grow in parallel and visually balance. Per-column stack indices
        // track how many letters have been placed in each column.
        var perColumnStackIndex = Array(repeating: 0, count: columnCount)
        for (i, _) in visibleSeen.enumerated() {
            let column = i % columnCount
            let stackIndex = perColumnStackIndex[column]
            perColumnStackIndex[column] += 1
            let y = baseY + CGFloat(stackIndex) * effectiveLetterHeight
            spawnLetterSprite(
                at: CGPoint(x: spawnX(forColumn: column), y: y),
                rotation: CGFloat.random(in: -0.04...0.04)
            )
        }

        // Drop new letters with stagger so they pile rather than co-spawn.
        // Each one picks whichever column currently has the fewest live letters
        // so the two columns stay roughly even as the week fills up.
        for (i, _) in sortedNew.enumerated() {
            let delay = SKAction.wait(forDuration: Double(i) * 0.06)
            let spawn = SKAction.run { [weak self] in
                guard let self else { return }
                let column = self.columnWithFewestLive()
                self.spawnLetterSprite(
                    at: CGPoint(x: self.spawnX(forColumn: column),
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
        let column = columnWithFewestLive()
        spawnLetterSprite(
            at: CGPoint(x: spawnX(forColumn: column), y: size.height + 24),
            rotation: CGFloat.random(in: -0.09...0.09)
        )
        onCountsChanged?()
    }

    // MARK: - Column geometry

    /// Center x of a column index. Both columns are horizontally centered as a
    /// group within the scene width.
    private func columnCenterX(_ column: Int) -> CGFloat {
        let totalLettersWidth = CGFloat(columnCount) * letterSize.width
        let totalGapWidth = CGFloat(max(0, columnCount - 1)) * columnGap
        let groupWidth = totalLettersWidth + totalGapWidth
        let leftMargin = (size.width - groupWidth) / 2
        return leftMargin + CGFloat(column) * (letterSize.width + columnGap) + letterSize.width / 2
    }

    /// Spawn x for a column with a small horizontal jitter that stays well
    /// inside the column's lane (no leaking into the neighboring column).
    private func spawnX(forColumn column: Int) -> CGFloat {
        let jitter = CGFloat.random(in: -3...3)
        return clampedX(columnCenterX(column) + jitter)
    }

    /// Best-matching column for a live letter based on its current x position.
    private func columnFor(_ node: SKNode) -> Int {
        let x = node.position.x
        var best = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for c in 0..<columnCount {
            let d = abs(x - columnCenterX(c))
            if d < bestDist { bestDist = d; best = c }
        }
        return best
    }

    private func columnWithFewestLive() -> Int {
        var counts = Array(repeating: 0, count: columnCount)
        for node in letterOrder {
            counts[columnFor(node)] += 1
        }
        return counts.indices.min(by: { counts[$0] < counts[$1] }) ?? 0
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
        let impulse = CGVector(dx: -dx * windowImpulseScale, dy: -dy * windowImpulseScale)
        for node in letterOrder {
            node.physicsBody?.applyImpulse(impulse)
        }
    }

    // MARK: - Per-frame work

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard !letterOrder.isEmpty, size.height > 0 else { return }

        // Track peak settled-pile height for the chalk-mark. Letters above the
        // window (mid-air projectiles) don't count toward "pile height".
        var topY: CGFloat = 0
        for n in letterOrder where n.position.y <= size.height && n.position.y > topY {
            topY = n.position.y
        }
        if topY > bestPileHeight {
            bestPileHeight = topY
            UserDefaults.standard.set(Double(topY), forKey: bestHeightKey)
            updateChalkMarkPosition()
        }

        // Overflow trigger: count-based, not height-based. Spawning a new letter
        // briefly pushes letterOrder.count to maxVisibleLetters+1; we compact
        // the oldest exactly once and return to the cap. No cascade.
        if letterOrder.count > maxVisibleLetters {
            compactOldestLetter()
        }
    }

    private func compactOldestLetter() {
        guard letterOrder.count > 1, let oldest = letterOrder.first else { return }
        oldest.removeFromParent()
        letterOrder.removeFirst()

        if let block = compactedBlock {
            let newHeight = min(maxBlockHeight, block.size.height + blockHeightPerLetter)
            block.size = CGSize(width: size.width, height: newHeight)
        }
        updateBlockPhysics()
        updateCompactedDivider()
        onCountsChanged?()
    }
}
