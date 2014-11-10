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
		func toString() -> String {
			switch(self) {
			case .NodeIndex(let item):
				return String(item)
			case .TextIndex(let item):
				return String(item)
			}
		}
		
		case NodeIndex(item: Array<ViRopeNode>.Index)
		case TextIndex(item: Array<String>.Index)
	}
	
	private let root: ViRopeNode
	private let nodeIndices: [Range<Index>] = []
	
	/// A character position in a `ViRope`.
	struct Index : BidirectionalIndexType, Comparable, Printable {
		var description: String {
			get {
				return "ViRope.Index [path: \(nodePath)] [text: \(nodeText)] [index: \(nodeIndex)]"
			}
		}
		
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
						var updatedTextIndex = textIndex + 1
						// Skip empty strings.
						while (updatedTextIndex != node.childText.endIndex && node.childText[updatedTextIndex].startIndex == node.childText[updatedTextIndex].endIndex) {
							updatedTextIndex += 1
						}
						
						if updatedTextIndex == node.childText.endIndex {
							return updatedIndex
						} else {
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
			
			if nodeText == nil || nodeIndex == nil {
				println("fatal error: can not increment end index")
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
		
		private func findPreviousNodeIndex() -> Index? {
			// we already know we want the next available node
			// for the last entry in the path, check if there is a next child text
			return nodePath.reverse().reduce(self, combine: { (updatedIndex, nodeEntry) -> Index? in
				if updatedIndex != self && updatedIndex != nil {
					return updatedIndex
				} else {
					let (node, index) = nodeEntry
					
					switch index {
					case .NodeIndex(let childIndex):
						return nil
					case .TextIndex(let textIndex):
						if textIndex == node.childText.startIndex {
							return nil
						} else {
							var updatedTextIndex = textIndex
							// Skip empty strings.
							do {
								updatedTextIndex -= 1
							} while (updatedTextIndex != node.childText.startIndex && node.childText[updatedTextIndex].startIndex == node.childText[updatedTextIndex].endIndex)
							
							var seen = false
							var updatedPath = self.nodePath.filter({ (pathNode, nodeIndex) -> Bool in
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
							
							return Index(nodePath: updatedPath, nodeText: updatedText, nodeIndex: updatedText.endIndex.predecessor())
						}
					}
				}
			})
		}
		
		/// Returns the previous consecutive value before `self`.
		///
		/// Requires: the previous value is representable.
		func predecessor() -> Index {
			if nodeText == nil || nodeIndex == nil {
				println("fatal error: can not decrement start index")
				abort()
			} else if nodeIndex == nodeText?.startIndex {
				let previousNodeIndex = findPreviousNodeIndex()
				
				if let previousIndex = previousNodeIndex {
					return previousIndex
				} else { // special marker, means nothing's before
					println("fatal error: can not decrement start index")
					abort()
				}
			} else {
				let previousInText = nodeIndex?.predecessor()
				
				return Index(nodePath: nodePath, nodeText: nodeText, nodeIndex: previousInText)
			}
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
	
	subscript(index: Index) -> Character {
		get {
			if index.nodeIndex != nil && index.nodeText != nil {
				// oh for comprehension, where art thou
				return index.nodeText![index.nodeIndex!]
			} else {
				println("fatal error: Can't form a Character from an empty String")
				abort()
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