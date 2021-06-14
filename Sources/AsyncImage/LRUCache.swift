import Foundation

protocol MemoryCostValue {
    var memoryCost: Int { get }
}

final class LRUCache<Key: Hashable, Value: MemoryCostValue> {
    final class Node {
        var next: Node?
        var previous: Node?
        let key: Key
        var value: Value
        
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    let capacity: Int
    var totalCount: Int
    var head: Node?
    var tail: Node?
    var map = [Key: Node]()
    
    init(_ capacity: Int) {
        self.capacity = capacity
        self.totalCount = 0
    }
    
    subscript(key: Key) -> Value? {
        get {
            guard let node = map[key] else {
                return nil
            }
            moveToFront(node: node)
            return node.value
        }
        set {
            guard let newValue = newValue else {
                map[key].map(deleteNode)
                return
            }
            if let node = map[key] {
                node.value = newValue
                moveToFront(node: node)
            } else {
                let node = Node(key: key, value: newValue)
                insertHead(node)
                map[key] = node
                totalCount += node.value.memoryCost
                while totalCount > capacity, let node = deleteTail() {
                    totalCount -= node.value.memoryCost
                    map[node.key] = nil
                }
            }
        }
    }
    
    func moveToFront(node: Node) {
        deleteNode(node)
        insertHead(node)
    }
    
    func insertHead(_ node: Node) {
        head?.previous = node
        node.next = head
        node.previous = nil
        head = node
        if tail == nil {
            tail = node
        }
    }
    
    func deleteNode(_ node: Node) {
        if node === tail { tail = node.previous }
        if node === head { head = node.next }
        node.previous?.next = node.next
        node.next?.previous = node.previous
    }
    
    func deleteTail() -> Node? {
        guard let node = tail else { return nil }
        node.previous?.next = nil
        tail = node.previous
        return node
    }
}
