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
	return lhs.nodeText == rhs.nodeText && lhs.nodeIndex == rhs.nodeIndex
}

class ViRope {
	
	private class ViRopeNode {
		let children: [ViRopeNode]
		let childText: [String]
		
		init(children: [ViRopeNode]) {
			self.children = children
			childText = []
		}
		
		init(childText: [String]) {
			self.childText = childText
			children = []
		}
	}
	
	private enum EitherIndex {
		case NodeIndex(item: Array<ViRopeNode>.Index)
		case TextIndex(item: Array<String>.Index)
	}
	
	private let root: ViRopeNode
	private let nodeIndices: [Range<Index>] = []
	
	/// A character position in a `ViRope`.
	struct Index : BidirectionalIndexType, Comparable {
		/// The path of nodes from root to the node that holds the string; the index is the index within the node's contents that the next node is at.
		private let nodePath: [(ViRopeNode, EitherIndex)]
		private let nodeText: String?
		/// The string index within the text node that this index represents. Expected to be non-nil if nodePath is non-nil.
		private let nodeIndex: String.Index?
		
		private func findNextNodeIndex() -> Index {
			// we already know we want the next available node
			// for the last entry in the path, check if there is a next child text
			return nodePath.reverse().reduce(self, combine: { (updatedIndex, nodeEntry) -> Index in
				if updatedIndex != self {
					return updatedIndex
				} else {
					let (node, index) = nodeEntry
					
					switch index {
					case .NodeIndex(let childIndex):
						return updatedIndex
					case .TextIndex(let textIndex):
						if textIndex + 1 == node.childText.endIndex {
							return updatedIndex
						} else {
							let updatedTextIndex = textIndex + 1
							
							var seen = false
							var updatedPath = updatedIndex.nodePath.filter({ (pathNode, nodeIndex) -> Bool in
								if pathNode === node {
									seen = true
									return true
								} else {
									return !seen
								}
							})
							updatedPath[updatedPath.endIndex - 1] =
								(node, .TextIndex(item: updatedTextIndex))
							let updatedText = node.childText[updatedTextIndex]

							return Index(nodePath: updatedPath, nodeText: updatedText, nodeIndex: updatedText.startIndex)
						}
					}
				}
			})
		}
		
		/// Returns the next consecutive value after `self`.
		///
		/// Requires: the next value is representable.
		func successor() -> Index {
			let nextInText = nodeIndex?.successor()
			
			if nodeText == nil {
				println("fatal error: cannot increment end index")
				abort()
			} else if nextInText == nodeText?.endIndex {
				let nextNodeIndex = findNextNodeIndex()
				
				if nextNodeIndex == self { // special marker, means nothing's next
					return Index(nodePath: nodePath, nodeText: nodeText, nodeIndex: nextInText)
				} else {
					return nextNodeIndex
				}
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
			if let firstText = root.childText.first {
				return Index(
					nodePath: [(root, .TextIndex(item: root.childText.startIndex))],
					nodeText: firstText,
					nodeIndex: firstText.startIndex)
			} else {
				return Index(nodePath: [], nodeText: nil, nodeIndex: nil)
			}
		}
	}
	var endIndex: Index {
		get {
			if let lastText = root.childText.last {
				return Index(
					nodePath: [(root, .TextIndex(item: root.childText.endIndex))],
					nodeText: lastText,
					nodeIndex: lastText.endIndex)
			} else {
				return Index(nodePath: [], nodeText: nil, nodeIndex: nil)
			}
		}
	}
	
	subscript(index: Index) -> Character? {
		get {
			if let nodeIndex = index.nodeIndex {
				return index.nodeText?[nodeIndex]
			} else {
				return nil
			}
		}
	}
	
	init(_ string: String) {
		root = ViRopeNode(childText: [string])
		nodeIndices = [Range(start: startIndex, end: endIndex)]
	}
	private init(updatedNodes: [String], indices: [Range<ViRope.Index>]) {
		root = ViRopeNode(childText: updatedNodes)
		nodeIndices = indices
	}
	init() {
		root = ViRopeNode(childText: [])
	}
	
	func append(string: String) -> ViRope {
		if let lastNode = root.childText.last {
			let range = Range(start: startIndex, end: endIndex)
			return ViRope(updatedNodes: root.childText + [string], indices: [range])
		} else {
			return ViRope(updatedNodes: [string], indices: [Range(start: startIndex, end: endIndex)])
		}
	}
	
	func insert(string: String, atIndex: Int) -> ViRope {
		let (_, updatedNodes) = root.childText.reduce((0, []), combine: { (progressInfo, node) -> (Int,[String]) in
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
		return root.childText.reduce(0, combine: { $0 + countElements($1) })
	}
	
	func toString() -> String {
		return join("", root.childText)
	}
}