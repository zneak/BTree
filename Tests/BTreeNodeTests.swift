//
//  BTreeNodeTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-21.
//  Copyright © 2015–2016 Károly Lőrentey.
//

import XCTest
@testable import BTree

class BTreeNodeTests: XCTestCase {
    typealias Node = BTreeNode<Int, String>
    let order = 7

    func testEmptyNode() {
        let node = Node(order: order)
        node.assertValid()

        XCTAssertEqual(node.elements.count, 0)
        XCTAssertEqual(node.children.count, 0)
        XCTAssertEqual(node.count, 0)
        XCTAssertEqual(node.order, order)
        XCTAssertEqual(node.depth, 0)

        XCTAssertTrue(node.isEmpty)
        assertEqualElements(node, [])
    }

    func testDefaultOrder() {
        XCTAssertLessThanOrEqual(Node.defaultOrder * strideof(Int), bTreeNodeSize)
    }

    func testNodeRootInit() {
        let left = maximalNode(depth: 1, order: order, offset: 0)
        let separator = (left.count, String(left.count))
        let right = maximalNode(depth: 1, order: order, offset: left.count + 1)

        let node = Node(left: left, separator: separator, right: right)
        node.assertValid()

        assertEqualElements(node.elements, [separator])
        XCTAssertEqual(node.children.count, 2)
        XCTAssertTrue(node.children[0] === left)
        XCTAssertTrue(node.children[1] === right)
        XCTAssertEqual(node.count, left.count + 1 + right.count)

        assertEqualElements(node, (0..<node.count).map { ($0, String($0)) })
    }

    func testNodeInitRange() {
        let source = maximalNode(depth: 1, order: 5)
        let node = Node(node: source, slotRange: 1..<3)

        assertEqualElements(node.elements, [(9, "9"), (14, "14")])
        XCTAssertEqual(node.depth, 1)
        XCTAssertEqual(node.children.count, 3)
        XCTAssertTrue(node.children[0] === source.children[1])
        XCTAssertTrue(node.children[1] === source.children[2])
        XCTAssertTrue(node.children[2] === source.children[3])
        XCTAssertEqual(node.count, 14)
        XCTAssertEqual(node.order, 5)
        XCTAssertEqual(node.depth, 1)

        let node2 = Node(node: maximalNode(depth: 0, order: 5), slotRange: 1..<3)
        assertEqualElements(node2.elements, [(1, "1"), (2, "2")])
        XCTAssertEqual(node2.children.count, 0)
        XCTAssertEqual(node2.count, 2)
        XCTAssertEqual(node2.order, 5)
        XCTAssertEqual(node2.depth, 0)

        let node3 = Node(node: source, slotRange: 1..<1)
        assertEqualElements(node3.elements, [(5, "5"), (6, "6"), (7, "7"), (8, "8")])
        XCTAssertEqual(node3.depth, 0)
        XCTAssertEqual(node3.children.count, 0)
        XCTAssertEqual(node3.count, 4)
        XCTAssertEqual(node3.order, 5)
        XCTAssertEqual(node3.depth, 0)

    }

    func testMakeChildUnique() {
        let node = maximalNode(depth: 1, order: 5)
        weak var origChild2: Node? = node.children[2]
        let uniqChild2 = node.makeChildUnique(2)
        XCTAssertTrue(origChild2 === uniqChild2)
        XCTAssertTrue(node.children[2] === uniqChild2)

        let origChild3 = node.children[3]
        let uniqChild3 = node.makeChildUnique(3)
        XCTAssertFalse(origChild3 === uniqChild3)
        XCTAssertTrue(node.children[3] === uniqChild3)
    }

    func testClone() {
        let node = maximalNode(depth: 1, order: 5)
        let clone = node.clone()

        XCTAssertFalse(node === clone)
        assertEqualElements(node.elements, clone.elements)
        XCTAssertEqual(node.children.count, clone.children.count)
        for i in 0..<node.children.count {
            XCTAssertTrue(node.children[i] === clone.children[i])
        }
        XCTAssertEqual(node.count, clone.count)
        XCTAssertEqual(node.order, clone.order)
        XCTAssertEqual(node.depth, clone.depth)
    }

    func testBasicLimits() {
        let node = maximalNode(depth: 1, order: 5)

        XCTAssertEqual(node.maxChildren, 5)
        XCTAssertEqual(node.minChildren, 3)
        XCTAssertEqual(node.maxKeys, 4)
        XCTAssertEqual(node.minKeys, 2)
    }

    func testBasicProperties() {
        let node = maximalNode(depth: 1, order: 5)

        XCTAssertFalse(node.isLeaf)
        XCTAssertFalse(node.isTooSmall)
        XCTAssertFalse(node.isTooLarge)
        XCTAssertTrue(node.isBalanced)
    }

    func testGenerateOnEmptyNode() {
        let node = Node(order: 5)
        assertEqualElements(GeneratorSequence(node.generate()), [])
    }
    
    func testGenerateOnNonemptyNode() {
        let node = maximalNode(depth: 2, order: 5)

        assertEqualElements(GeneratorSequence(node.generate()), (0..<124).map { ($0, String($0)) })
    }

    func testStandardForEach() {
        let node = maximalNode(depth: 2, order: 5)

        var i = 0
        node.forEach { (key, value) -> Void in
            XCTAssertEqual(key, i)
            XCTAssertEqual(value, String(i))
            i += 1
        }
        XCTAssertEqual(i, 24 * 5 + 4)
    }

    func testInterruptibleForEach() {
        let node = maximalNode(depth: 2, order: 5)

        var i = 0
        XCTAssertTrue(node.forEach { (key, value) -> Bool in
            XCTAssertEqual(key, i)
            XCTAssertEqual(value, String(i))
            i += 1
            return true
        })
        XCTAssertEqual(i, 24 * 5 + 4)

        i = 0
        XCTAssertFalse(node.forEach { _,_ in i += 1; return false })
        XCTAssertEqual(i, 1)

        i = 0
        XCTAssertFalse(node.forEach { (key, value) -> Bool in
            XCTAssertLessThan(i, 100)
            i += 1
            return i != 100
        })
        XCTAssertEqual(i, 100)

        i = 0
        XCTAssertFalse(node.forEach { (key, value) -> Bool in
            XCTAssertLessThan(i, 120)
            i += 1
            return i != 120
            })
        XCTAssertEqual(i, 120)
    }

    func testSetElementInSlot() {
        let node = maximalNode(depth: 1, order: 5)

        let element = node.setElementInSlot(2, to: (-1, "Foo"))
        XCTAssertEqual(element.0, 14)
        XCTAssertEqual(element.1, "14")
        XCTAssertEqual(node.elements[2].0, -1)
        XCTAssertEqual(node.elements[2].1, "Foo")
    }

    func testInsertElementInSlot() {
        let node = maximalNode(depth: 0, order: 5)

        node.insert((-1, "Foo"), inSlot: 2)
        XCTAssertEqual(node.count, 5)
        XCTAssertTrue(node.isTooLarge)
        assertEqualElements(node.elements, [(0, "0"), (1, "1"), (-1, "Foo"), (2, "2"), (3, "3")])
    }

    func testAppendElement() {
        let node = maximalNode(depth: 0, order: 5)
        node.append((4, "4"))

        XCTAssertTrue(node.isTooLarge)
        assertEqualElements(node, (0..<5).map { ($0, String($0)) })
    }

    func testRemoveSlot() {
        let node = maximalNode(depth: 0, order: 5)
        let element = node.removeSlot(2)
        XCTAssertEqual(element.0, 2)
        XCTAssertEqual(element.1, "2")
        XCTAssertEqual(node.count, 3)
        assertEqualElements(node, [(0, "0"), (1, "1"), (3, "3")])
    }

    func testSlotOfKey() {
        let node = maximalNode(depth: 0, order: 100)
        node.removeSlot(45)
        node.setElementInSlot(26, to: (25, "25"))
        XCTAssertEqual(node.count, 98)

        for selector in [BTreeKeySelector.First, .Any] { // .Any means .First here
            XCTAssertEqual(node.slotOf(-1, choosing: selector).match, nil)
            XCTAssertEqual(node.slotOf(-1, choosing: selector).descend, 0)
            XCTAssertEqual(node.slotOf(0, choosing: selector).match, 0)
            XCTAssertEqual(node.slotOf(0, choosing: selector).descend, 0)
            XCTAssertEqual(node.slotOf(44, choosing: selector).match, 44)
            XCTAssertEqual(node.slotOf(44, choosing: selector).descend, 44)
            XCTAssertEqual(node.slotOf(45, choosing: selector).match, nil)
            XCTAssertEqual(node.slotOf(45, choosing: selector).descend, 45)
            XCTAssertEqual(node.slotOf(25, choosing: selector).match, 25)
            XCTAssertEqual(node.slotOf(25, choosing: selector).descend, 25)
            XCTAssertEqual(node.slotOf(98, choosing: selector).match, 97)
            XCTAssertEqual(node.slotOf(98, choosing: selector).descend, 97)
            XCTAssertEqual(node.slotOf(99, choosing: selector).match, nil)
            XCTAssertEqual(node.slotOf(99, choosing: selector).descend, 98)
        }

        XCTAssertEqual(node.slotOf(-1, choosing: .Last).match, nil)
        XCTAssertEqual(node.slotOf(-1, choosing: .Last).descend, 0)
        XCTAssertEqual(node.slotOf(0, choosing: .Last).match, 0)
        XCTAssertEqual(node.slotOf(0, choosing: .Last).descend, 1)
        XCTAssertEqual(node.slotOf(44, choosing: .Last).match, 44)
        XCTAssertEqual(node.slotOf(44, choosing: .Last).descend, 45)
        XCTAssertEqual(node.slotOf(45, choosing: .Last).match, nil)
        XCTAssertEqual(node.slotOf(45, choosing: .Last).descend, 45)
        XCTAssertEqual(node.slotOf(25, choosing: .Last).match, 26)
        XCTAssertEqual(node.slotOf(25, choosing: .Last).descend, 27)
        XCTAssertEqual(node.slotOf(98, choosing: .Last).match, 97)
        XCTAssertEqual(node.slotOf(98, choosing: .Last).descend, 98)
        XCTAssertEqual(node.slotOf(99, choosing: .Last).match, nil)
        XCTAssertEqual(node.slotOf(99, choosing: .Last).descend, 98)

        XCTAssertEqual(node.slotOf(-1, choosing: .After).match, 0)
        XCTAssertEqual(node.slotOf(-1, choosing: .After).descend, 0)
        XCTAssertEqual(node.slotOf(0, choosing: .After).match, 1)
        XCTAssertEqual(node.slotOf(0, choosing: .After).descend, 1)
        XCTAssertEqual(node.slotOf(44, choosing: .After).match, 45)
        XCTAssertEqual(node.slotOf(44, choosing: .After).descend, 45)
        XCTAssertEqual(node.slotOf(45, choosing: .After).match, 45)
        XCTAssertEqual(node.slotOf(45, choosing: .After).descend, 45)
        XCTAssertEqual(node.slotOf(25, choosing: .After).match, 27)
        XCTAssertEqual(node.slotOf(25, choosing: .After).descend, 27)
        XCTAssertEqual(node.slotOf(98, choosing: .After).match, nil)
        XCTAssertEqual(node.slotOf(98, choosing: .After).descend, 98)
        XCTAssertEqual(node.slotOf(99, choosing: .After).match, nil)
        XCTAssertEqual(node.slotOf(99, choosing: .After).descend, 98)
    }

    func testSlotOfOffset() {
        let leaf = maximalNode(depth: 0, order: 5)
        for i in 0 ..< 5 {
            XCTAssertEqual(leaf.slotOfOffset(i).index, i)
            XCTAssertEqual(leaf.slotOfOffset(i).match, true)
            XCTAssertEqual(leaf.slotOfOffset(i).offset, i)
        }

        let node = maximalNode(depth: 1, order: 3)
        var p = 0
        for i in 0 ..< 3 {
            XCTAssertEqual(node.slotOfOffset(p).index, i)
            XCTAssertEqual(node.slotOfOffset(p).match, false)
            XCTAssertEqual(node.slotOfOffset(p).offset, p + 2)

            XCTAssertEqual(node.slotOfOffset(p + 1).index, i)
            XCTAssertEqual(node.slotOfOffset(p + 1).match, false)
            XCTAssertEqual(node.slotOfOffset(p + 1).offset, p + 2)

            XCTAssertEqual(node.slotOfOffset(p + 2).index, i)
            XCTAssertEqual(node.slotOfOffset(p + 2).match, i != 2)
            XCTAssertEqual(node.slotOfOffset(p + 2).offset, p + 2)

            p += 3
        }
        XCTAssertEqual(p, node.count + 1)
    }

    func testOffsetOfSlot() {
        let leaf = maximalNode(depth: 0, order: 5)
        XCTAssertEqual(leaf.offsetOfSlot(2), 2)

        let node = maximalNode(depth: 2, order: 3)
        XCTAssertEqual(node.offsetOfSlot(0), 8)
        XCTAssertEqual(node.offsetOfSlot(1), 17)
        XCTAssertEqual(node.offsetOfSlot(2), 26)
    }

    func testEditWithWeakReferences() {
        let node = maximalNode(depth: 5, order: 3)
        var path = [Weak(node)]
        node.edit(
            descend: { node in
                XCTAssertTrue(node === path.last!.value)
                if node.isLeaf {
                    path.removeLast()
                    return nil
                }
                path.append(Weak(node.children[1]))
                return 1
            },
            ascend: { node, slot in
                XCTAssertTrue(node === path.last!.value)
                XCTAssertEqual(slot, 1)
                path.removeLast()
            }
        )
        XCTAssertEqual(path.count, 0)
    }

    func testEditWithStrongReferences() {
        let root = maximalNode(depth: 5, order: 3)
        var path = [root]
        root.edit(
            descend: { node in
                XCTAssertTrue(node === root || node !== path.last!)
                if node.isLeaf {
                    path.removeLast()
                    return nil
                }
                path[path.count - 1] = node
                path.append(node.children[1])
                return 1
            },
            ascend: { node, slot in
                XCTAssertTrue(node === path.last!)
                XCTAssertEqual(slot, 1)
                path.removeLast()
            }
        )
        XCTAssertEqual(path.count, 0)
    }

    func testDefaultSplit() {
        let node = maximalNode(depth: 0, order: 10)
        node.append((9, "9"))

        XCTAssertTrue(node.isTooLarge)
        let splinter = node.split()

        XCTAssertEqual(node.count, 5)
        assertEqualElements(node.map { $0.0 }, 0..<5)
        XCTAssertEqual(splinter.separator.0, 5)
        XCTAssertEqual(splinter.node.count, 4)
        assertEqualElements(splinter.node.map { $0.0 }, 6..<10)
    }

    func testRotations() {
        let node = uniformNode(depth: 2, order: 7, keysPerNode: 4)
        let c = node.count

        XCTAssertEqual(node.elements.map { $0.0 }, [24, 49, 74, 99])
        XCTAssertEqual(node.children.map { $0.count }, [24, 24, 24, 24, 24])

        node.rotateLeft(2)

        node.assertValid()
        assertEqualElements(node.map { $0.0 }, 0 ..< c)
        XCTAssertEqual(node.elements.map { $0.0 }, [24, 49, 79, 99])
        XCTAssertEqual(node.children.map { $0.count }, [24, 24, 29, 19, 24])

        node.rotateRight(2)

        node.assertValid()
        assertEqualElements(node.map { $0.0 }, 0 ..< c)
        XCTAssertEqual(node.elements.map { $0.0 }, [24, 44, 79, 99])
        XCTAssertEqual(node.children.map { $0.count }, [24, 19, 34, 19, 24])
    }

    func testCollapse() {
        let node = uniformNode(depth: 3, order: 7, keysPerNode: 4)
        let c = node.count
        XCTAssertEqual(node.children.map { $0.elements.count }, [4, 4, 4, 4, 4])
        node.rotateRight(3)
        XCTAssertEqual(node.children.map { $0.elements.count }, [4, 4, 3, 5, 4])
        node.rotateRight(3)
        XCTAssertEqual(node.children.map { $0.elements.count }, [4, 4, 2, 6, 4])
        node.rotateLeft(0)
        XCTAssertEqual(node.children.map { $0.elements.count }, [5, 3, 2, 6, 4])
        node.collapse(1)
        node.assertValid()
        XCTAssertEqual(node.children.count, 4)
        XCTAssertEqual(node.children.map { $0.elements.count }, [5, 6, 6, 4])
        assertEqualElements(node.map { $0.0 }, 0 ..< c)
    }

    func testFixDeficiencyByRotatingLeft() {
        let node = minimalNode(depth: 1, order: 5)
        let c = node.count
        node.children[2].insert(node.setElementInSlot(1, to: node.children[1].removeSlot(1)), inSlot: 0)
        node.fixDeficiency(1)
        node.assertValid()
        assertEqualElements(node.map { $0.0 }, 0 ..< c)
    }

    func testFixDeficiencyByRotatingRight() {
        let node = minimalNode(depth: 1, order: 5)
        let c = node.count
        node.children[1].append(node.setElementInSlot(1, to: node.children[2].removeSlot(0)))
        node.fixDeficiency(2)
        node.assertValid()
        assertEqualElements(node.map { $0.0 }, 0 ..< c)
    }

    func testJoin() {
        let left = maximalNode(depth: 4, order: 3)
        let separator = (left.count, String(left.count))
        let right = maximalNode(depth: 4, order: 3, offset: left.count + 1)

        let combined = Node.join(left: left, separator: separator, right: right)
        combined.assertValid()
        assertEqualElements(combined.map { $0.0 }, 0 ..< (left.count + 1 + right.count))
    }

    func testMoreJoin() {
        func createNode(keys: Range<Int> = 0..<0) -> Node {
            let tree = BTree(sortedElements: keys.map { ($0, String($0)) }, order: 5)
            return tree.root
        }
        func checkNode(n: Node, _ keys: Range<Int>, file: StaticString = #file, line: UInt = #line) {
            n.assertValid(file: file, line: line)
            assertEqualElements(n, keys.map { ($0, String($0)) }, file: file, line: line)
        }

        checkNode(Node.join(left: createNode(), separator: (0, "0"), right: createNode()), 0...0)
        checkNode(Node.join(left: createNode(), separator: (0, "0"), right: createNode(1...1)), 0...1)
        checkNode(Node.join(left: createNode(0...0), separator: (1, "1"), right: createNode()), 0...1)
        checkNode(Node.join(left: createNode(0...0), separator: (1, "1"), right: createNode(2...2)), 0...2)

        checkNode(Node.join(left: createNode(0...98), separator: (99, "99"), right: createNode(100...100)), 0...100)
        checkNode(Node.join(left: createNode(0...0), separator: (1, "1"), right: createNode(2...100)), 0...100)
        checkNode(Node.join(left: createNode(0...99), separator: (100, "100"), right: createNode(101...200)), 0...200)

        do {
            let l = maximalNode(depth: 2, order: 3)
            let r = maximalNode(depth: 2, order: 3, offset: l.count + 1)
            let s = (l.count, String(l.count))
            let c = l.count + r.count + 1
            checkNode(Node.join(left: l, separator: s, right: r), 0..<c)
        }

        do {
            let l = maximalNode(depth: 1, order: 3)
            let r = maximalNode(depth: 2, order: 3, offset: l.count + 1)
            let s = (l.count, String(l.count))
            let c = l.count + r.count + 1
            checkNode(Node.join(left: l, separator: s, right: r), 0..<c)
        }

        do {
            let l = maximalNode(depth: 2, order: 3)
            let r = maximalNode(depth: 1, order: 3, offset: l.count + 1)
            let s = (l.count, String(l.count))
            let c = l.count + r.count + 1
            checkNode(Node.join(left: l, separator: s, right: r), 0..<c)
        }
    }

    func testJoinWithDuplicateKeys() {
        let left = BTree(sortedElements: (0..<50).map { (0, $0) }, order: 3).root
        let sep = (0, 50)
        let right = BTree(sortedElements: (51..<100).map { (0, $0) }, order: 3).root
        let node = BTreeNode.join(left: left, separator: sep, right: right)
        node.assertValid()
        assertEqualElements(node, (0..<100).map { (0, $0) })
    }
}
