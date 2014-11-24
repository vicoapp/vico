//
//  ViRope.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 11/1/14.
//
//

import Foundation

class ViRope {
	
	internal let root: ViRopeNode<String>
	
	/// A character position in a `ViRope`.
	typealias Index = RopeIndexType<String>
	
	var startIndex: Index {
		get {
			return startIndexFor(root)
		}
	}
	var endIndex: Index {
		get {
			return endIndexFor(root)
		}
	}
	
	subscript(index: Index) -> Character {
		get {
			if let indexValue = index.value {
				return indexValue
			} else {
				println("fatal error: Can't form a Character from an empty String")
				abort()
			}
		}
	}
	
	subscript(integerIndex: Int) -> Character {
		get {
			return contentForIntegerIndexInTree(root, integerIndex)
		}
	}
	
	init(_ string: String) {
		root = ViRopeNode(childContent: [string])
	}
	private init(updatedNodes: [String]) {
		root = ViRopeNode(childContent: updatedNodes)
	}
	init() {
		root = ViRopeNode(childContent: [])
	}
	
	func append(string: String) -> ViRope {
		if let lastNode = root.childContent.last {
			let range = Range(start: startIndex, end: endIndex)
			return ViRope(updatedNodes: root.childContent + [string])
		} else {
			return ViRope(updatedNodes: [string])
		}
	}
	
	func insert(string: String, atIndex: Int) -> ViRope {
		let (_, updatedNodes) = root.childContent.reduce((0, []), combine: { (progressInfo, node) -> (Int,[String]) in
			let (latestIndex, nodesSoFar) = progressInfo
			let count = countElements(node)
			let endIndex = latestIndex + count
			
			if endIndex == atIndex {
				return (endIndex + 1, nodesSoFar + [node, string])
			} else if endIndex > atIndex && atIndex > latestIndex {
				let splitIndex = advance(node.startIndex, atIndex - latestIndex)
				
				return (endIndex,
					nodesSoFar +
						[node.substringWithRange(Range(start: node.startIndex, end: splitIndex)),
						string,
						node.substringWithRange(Range(start: splitIndex, end: node.endIndex))])
			} else {
				return (endIndex, nodesSoFar + [node])
			}
		})
		
		return ViRope(updatedNodes: updatedNodes);
	}
	
	// FIXME make this use countElements instead
	func length() -> Int {
		return root.childContent.reduce(0, combine: { $0 + countElements($1) })
	}
	
	func toString() -> String {
		return join("", root.childContent)
	}
}