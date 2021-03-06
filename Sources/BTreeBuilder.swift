//
//  BTreeBuilder.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-28.
//  Copyright © 2016 Károly Lőrentey.
//


extension BTree {
    //MARK: Bulk loading initializers

    /// Create a new B-tree from elements of an unsorted sequence, using a stable sort algorithm.
    ///
    /// - Parameter elements: An unsorted sequence of arbitrary length.
    /// - Parameter order: The desired B-tree order. If not specified (recommended), the default order is used.
    /// - Complexity: O(count * log(`count`))
    /// - SeeAlso: `init(sortedElements:order:fillFactor:)` for a (faster) variant that can be used if the sequence is already sorted.
    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S, dropDuplicates: Bool = false, order: Int = Node.defaultOrder) {
        self.init(Node(order: order))
        withCursorAtEnd { cursor in
            for element in elements {
                cursor.move(to: element.0, choosing: .Last)
                let match = !cursor.isAtEnd && cursor.key == element.0
                if match {
                    if dropDuplicates {
                        cursor.element = element
                    }
                    else {
                        cursor.insertAfter(element)
                    }
                }
                else {
                    cursor.insert(element)
                }
            }
        }
    }

    /// Create a new B-tree from elements of a sequence sorted by key.
    ///
    /// - Parameter sortedElements: A sequence of arbitrary length, sorted by key.
    /// - Parameter order: The desired B-tree order. If not specified (recommended), the default order is used.
    /// - Parameter fillFactor: The desired fill factor in each node of the new tree. Must be between 0.5 and 1.0.
    ///      If not specified, a value of 1.0 is used, i.e., nodes will be loaded with as many elements as possible.
    /// - Complexity: O(count)
    /// - SeeAlso: `init(elements:order:fillFactor:)` for a (slower) unsorted variant.
    public init<S: SequenceType where S.Generator.Element == Element>(sortedElements elements: S, dropDuplicates: Bool = false, order: Int = Node.defaultOrder, fillFactor: Double = 1) {
        var generator = elements.generate()
        self.init(order: order, fillFactor: fillFactor, dropDuplicates: dropDuplicates, next: { generator.next() })
    }

    internal init(order: Int = Node.defaultOrder, fillFactor: Double = 1, dropDuplicates: Bool = false, @noescape next: () -> Element?) {
        precondition(order > 1)
        precondition(fillFactor >= 0.5 && fillFactor <= 1)
        let keysPerNode = Int(fillFactor * Double(order - 1) + 0.5)
        assert(keysPerNode >= (order - 1) / 2 && keysPerNode <= order - 1)

        var builder = BTreeBuilder<Key, Value>(order: order, keysPerNode: keysPerNode)
        if dropDuplicates {
            guard var buffer = next() else {
                self.init(Node(order: order))
                return
            }
            while let element = next() {
                precondition(buffer.0 <= element.0)
                if buffer.0 < element.0 {
                    builder.append(buffer)
                }
                buffer = element
            }
            builder.append(buffer)
        }
        else {
            var lastKey: Key? = nil
            while let element = next() {
                precondition(lastKey <= element.0)
                lastKey = element.0
                builder.append(element)
            }
        }
        self.init(builder.finish())
    }
}

private enum BuilderState {
    /// The builder needs a separator element.
    case Separator
    /// The builder is filling up a seedling node.
    case Element
}

/// A construct for efficiently building a fully loaded B-tree from a series of elements.
///
/// The bulk loading algorithm works growing a line of perfectly loaded saplings, in order of decreasing depth,
/// with a separator element between each of them.
///
/// Added elements are collected into a separator and a new leaf node (called the "seedling").
/// When the seedling becomes full it is appended to or recursively merged into the list of saplings.
///
/// When `finish` is called, the final list of saplings plus the last partial seedling is joined
/// into a single tree, which becomes the root.
internal struct BTreeBuilder<Key: Comparable, Value> {
    typealias Node = BTreeNode<Key, Value>
    typealias Element = Node.Element
    typealias Splinter = Node.Splinter

    private let order: Int
    private let keysPerNode: Int
    private var saplings: [Node]
    private var separators: [Element]
    private var seedling: Node
    private var state: BuilderState

    init(order: Int) {
        self.init(order: order, keysPerNode: order - 1)
    }
    
    init(order: Int, keysPerNode: Int) {
        precondition(order > 1)
        precondition(keysPerNode >= (order - 1) / 2 && keysPerNode <= order - 1)

        self.order = order
        self.keysPerNode = keysPerNode
        self.saplings = []
        self.separators = []
        self.seedling = Node(order: order)
        self.state = .Element
    }

    mutating func append(element: Element) {
        switch state {
        case .Separator:
            separators.append(element)
            state = .Element
        case .Element:
            seedling.append(element)
            if seedling.count == keysPerNode {
                closeSeedling()
                state = .Separator
            }
        }
    }

    private mutating func closeSeedling() {
        appendSapling(seedling)
        seedling = Node(order: order)
    }

    mutating func append(node: Node) {
        appendWithoutCloning(node.clone())
    }

    mutating func appendWithoutCloning(node: Node) {
        assert(node.order == order)
        if node.depth == 0 {
            if node.isEmpty { return }
            if state == .Separator {
                assert(seedling.isEmpty)
                separators.append(node.elements.removeFirst())
                node.count -= 1
                state = .Element
                if node.isEmpty { return }
                seedling = node
            }
            else if seedling.count > 0 {
                let sep = seedling.elements.removeLast()
                seedling.count -= 1
                if let splinter = seedling.shiftSlots(separator: sep, node: node, target: keysPerNode) {
                    closeSeedling()
                    separators.append(splinter.separator)
                    seedling = splinter.node
                }
            }
            else {
                seedling = node
            }
            if seedling.count >= keysPerNode {
                closeSeedling()
                state = .Separator
            }
            return
        }

        if state == .Element && seedling.count > 0 {
            let sep = seedling.elements.removeLast()
            seedling.count -= 1
            closeSeedling()
            separators.append(sep)
        }
        if state == .Separator {
            let cursor = BTreeCursor(BTreeCursorPath(endOf: saplings.removeLast()))
            cursor.moveBackward()
            let separator = cursor.remove()
            saplings.append(cursor.finish())
            separators.append(separator)
        }
        assert(seedling.isEmpty)
        appendSapling(node)
        state = .Separator
    }

    private mutating func appendSapling(sapling: Node) {
        var sapling = sapling
        outer: while !saplings.isEmpty {
            assert(saplings.count == separators.count)
            var previous = saplings.removeLast()
            let separator = separators.removeLast()

            // Join previous saplings together until they grow at least as deep as the new one.
            while previous.depth < sapling.depth {
                if saplings.isEmpty {
                    // If the single remaining sapling is too shallow, just join it to the new sapling and call it a day.
                    sapling = Node.join(left: previous, separator: separator, right: sapling)
                    break outer
                }
                previous = Node.join(left: saplings.removeLast(), separator: separators.removeLast(), right: previous)
            }

            let fullPrevious = previous.elements.count >= keysPerNode
            let fullSapling = sapling.elements.count >= keysPerNode

            if previous.depth == sapling.depth + 1 && !fullPrevious && fullSapling {
                // Graft node under the last sapling, as a new child branch.
                previous.elements.append(separator)
                previous.children.append(sapling)
                previous.count += sapling.count + 1
                sapling = previous
            }
            else if previous.depth == sapling.depth && fullPrevious && fullSapling {
                // We have two full nodes; add them as two branches of a new, deeper node.
                sapling = Node(left: previous, separator: separator, right: sapling)
            }
            else if previous.depth > sapling.depth || fullPrevious {
                // The new sapling can be appended to the line and we're done.
                saplings.append(previous)
                separators.append(separator)
                break
            }
            else if let splinter = previous.shiftSlots(separator: separator, node: sapling, target: keysPerNode) {
                // We have made the previous sapling full; add it as a new one before trying again with the remainder.
                assert(previous.elements.count == keysPerNode)
                appendSapling(previous)
                separators.append(splinter.separator)
                sapling = splinter.node
            }
            else {
                // We've combined the two saplings; try again with the result.
                sapling = previous
            }
        }
        saplings.append(sapling)
    }

    @warn_unused_result
    mutating func finish() -> Node {
        // Merge all saplings and the seedling into a single tree.
        var root: Node
        if separators.count == saplings.count - 1 {
            assert(seedling.count == 0)
            root = saplings.removeLast()
        }
        else {
            root = seedling
        }
        assert(separators.count == saplings.count)
        while !saplings.isEmpty {
            root = Node.join(left: saplings.removeLast(), separator: separators.removeLast(), right: root)
        }
        state = .Element
        return root
    }
}