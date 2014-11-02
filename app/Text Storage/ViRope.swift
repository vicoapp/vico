//
//  ViRope.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 11/1/14.
//
//

import Foundation


func <(lhs: ViRope.Index, rhs: ViRope.Index) -> Bool {
	return false
}

func ==(lhs: ViRope.Index, rhs: ViRope.Index) -> Bool {
	return false
}

class ViRope {
	
	private enum RopeContents {
		case Node([ViRopeNode])
		case Text(String)
	}
	
	private struct ViRopeNode {
		let children: [RopeContents]
	}
	
	private let root: ViRopeNode
	private let nodeIndices: [Range<Index>] = []
	
	/// A character position in a `ViRope`.
	struct Index : BidirectionalIndexType, Comparable {
		/// The path of nodes from root to the node that holds the string; the index is the index within the node's contents that the next node is at.
		private let nodePath: [(ViRopeNode, Array<ViRopeNode>.Index)]
		private let nodeText: String
		/// The string index within the text node that this index represents. Expected to be non-nil if nodePath is non-nil.
		private let nodeIndex: String
		
		private func findNextNodeIndex() -> Index {
			nodePath.reverse().reduce([], combine: { (things, (node, index)) -> thing in
				if index.successor() == node.children.endIndex {
					// parent's going to have to try
				} else {
					Index(nodePath: <#[(ViRope.ViRopeNode, Int)]#>, nodeText: <#String#>, nodeIndex: <#String#>)
				}
			})
		}
		
		/// Returns the next consecutive value after `self`.
		///
		/// Requires: the next value is representable.
		func successor() -> Index {
			let nextInText = nodeIndex.successor()
			
			if nextInText == nodeText.endIndex {
				return findNextNodeIndex()
			} else {
				return Index(nodePath: nodePath, nodeText: nodeText, nodeIndex: nextInText)
			}
		}
		
		/// Returns the previous consecutive value before `self`.
		///
		/// Requires: the previous value is representable.
		func predecessor() -> Index {
			// if first index, fatal error
			return self
		}
	}
	
	var startIndex: Index {
		get {
			return Index(nodePath: root.nodes.first, nodeIndex: root.nodes.first?.startIndex)
		}
	}
	var endIndex: Index {
		get {
			return Index(nodePath: root.nodes.last, nodeIndex: root.nodes.last?.endIndex)
		}
	}
	
	subscript(index: Index) -> Character {
		get {
			if let char = index.nodePath?[index.nodeIndex!] {
				return char
			} else {
				println("fatal error: Can't form a Character from an empty String")
				abort()
			}
		}
	}
	
	init(_ string: String) {
		root = ViRopeNode(nodes: [string])
		nodeIndices = [Range(start: startIndex, end: endIndex)]
	}
	private init(updatedNodes: [String], indices: [Range<ViRope.Index>]) {
		root = ViRopeNode(nodes: updatedNodes)
		nodeIndices = indices
	}
	init() {
		root = ViRopeNode(nodes: [])
	}
	
	func append(string: String) -> ViRope {
		if let lastNode = root.nodes.last {
			let range = Range(start: startIndex, end: endIndex)
			return ViRope(updatedNodes: root.nodes + [string], indices: [range])
		} else {
			return ViRope(updatedNodes: [string], indices: [Range(start: startIndex, end: endIndex)])
		}
	}
	
	func insert(string: String, atIndex: Int) -> ViRope {
		let (_, updatedNodes) = root.nodes.reduce((0, []), combine: { (progressInfo, node) -> (Int,[String]) in
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
		
		return ViRope(updatedNodes: updatedNodes, indices: [Range(start: startIndex, end: endIndex)]);
	}
	
	// FIXME make this use countElements instead
	func length() -> Int {
		return root.nodes.reduce(0, combine: { $0 + countElements($1) })
	}
	
	func toString() -> String {
		return join("", root.nodes)
	}
}