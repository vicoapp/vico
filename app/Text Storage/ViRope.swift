//
//  ViRope.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 11/1/14.
//
//

import Foundation


func <<T : CollectionType where T.Index : BidirectionalIndexType>(lhs: RopeIndexType<T>, rhs: RopeIndexType<T>) -> Bool {
	return false
}

func ==<T : Equatable>(lhs: RopeIndexType<T>, rhs: RopeIndexType<T>) -> Bool {
	return  lhs.nodeContent == rhs.nodeContent && lhs.nodeIndex == rhs.nodeIndex;
}

internal enum EitherRopeIndex<ContentType : CollectionType> {
	case NodeIndex(item: Array<ViRopeNode<ContentType>>.Index)
	case ContentIndex(item: Array<ContentType>.Index)
}

// We want to be able to cycle through indices of a tree of things with
// indices, so that we can iterate the whole thing as if it were contiguous
//
internal struct RopeIndexType<ContentType : CollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType> : BidirectionalIndexType, Comparable, Printable {
	var description: String {
		get {
			return "RopeIndexType [path: \(nodePath)] [content: \(nodeContent)] [index: \(nodeIndex)]"
		}
	}
	
	var value: ContentType._Element? {
		get {
			if nodeContent != nil && nodeIndex != nil {
				return nodeContent![nodeIndex!]
			} else {
				return nil
			}
		}
	}
	
	/// The path of nodes from root to the node that holds the string; the index is the index within the node's contents that the next node is at.
	private let nodePath: [(ViRopeNode<ContentType>, EitherRopeIndex<ContentType>)]
	private let nodeContent: ContentType?
	/// The content index within the content node that this index represents. Expected to be non-nil if nodePath is non-nil.
	private let nodeIndex: ContentType.Index?
	
	init(nodePath: [(ViRopeNode<ContentType>, EitherRopeIndex<ContentType>)], nodeContent: ContentType?, nodeIndex: ContentType.Index?) {
		self.nodePath = nodePath
		self.nodeContent = nodeContent
		self.nodeIndex = nodeIndex
	}
	
	private func findNextNodeIndex() -> RopeIndexType<ContentType> {
		// we already know we want the next available node
		// for the last entry in the path, check if there is a next child text
		return nodePath.reverse().reduce(self, combine: { (updatedIndex, nodeEntry) -> RopeIndexType<ContentType> in
			if updatedIndex != self {
				return updatedIndex
			} else {
				let (node, index) = nodeEntry
				
				switch index {
				case .NodeIndex(let childIndex):
					return updatedIndex
				case .ContentIndex(let contentIndex):
					var updatedContentIndex = contentIndex + 1
					
					// Skip empty strings.
					while (updatedContentIndex != node.childContent.endIndex && node.childContent[updatedContentIndex].startIndex == node.childContent[updatedContentIndex].endIndex) {
						updatedContentIndex += 1
					}
					
					if updatedContentIndex == node.childContent.endIndex {
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
							(node, .ContentIndex(item: updatedContentIndex))
						let updatedContent = node.childContent[updatedContentIndex]
						
						return RopeIndexType<ContentType>(nodePath: updatedPath, nodeContent: updatedContent, nodeIndex: updatedContent.startIndex)
						
					}
				}
			}
		})
	}

	/// Returns the next consecutive value after `self`.
	///
	/// Requires: the next value is representable.
	func successor() -> RopeIndexType<ContentType> {
		let nextInContent = nodeIndex?.successor()
		
		if nodeContent == nil || nodeIndex == nil {
			println("fatal error: can not increment end index")
			abort()
		} else if nextInContent == nodeContent?.endIndex {
			let nextNodeIndex = findNextNodeIndex()
			
			if nextNodeIndex == self { // special marker, means nothing's next
				return RopeIndexType<ContentType>(nodePath: nodePath, nodeContent: nodeContent, nodeIndex: nextInContent)
			} else {
				return nextNodeIndex
			}
		} else {
			return RopeIndexType<ContentType>(nodePath: nodePath, nodeContent: nodeContent, nodeIndex: nextInContent)
		}
	}
	
	
	private func findPreviousNodeIndex() -> RopeIndexType<ContentType>? {
		// we already know we want the next available node
		// for the last entry in the path, check if there is a next child text
		return nodePath.reverse().reduce(self, combine: { (updatedIndex, nodeEntry) -> RopeIndexType<ContentType>? in
			if updatedIndex != self && updatedIndex != nil {
				return updatedIndex
			} else {
				let (node, index) = nodeEntry
				
				switch index {
				case .NodeIndex(let childIndex):
					return nil
				case .ContentIndex(let contentIndex):
					if contentIndex == node.childContent.startIndex {
						return nil
					} else {
						var updatedContentIndex = contentIndex
						// Skip empty strings.
						do {
							updatedContentIndex -= 1
						} while (updatedContentIndex != node.childContent.startIndex && node.childContent[updatedContentIndex].startIndex == node.childContent[updatedContentIndex].endIndex)
						
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
							(node, .ContentIndex(item: updatedContentIndex))
						let updatedContent: ContentType = node.childContent[updatedContentIndex]
						
						return RopeIndexType<ContentType>(nodePath: updatedPath, nodeContent: updatedContent, nodeIndex: updatedContent.endIndex.predecessor())
					}
				}
			}
		})
	}
	
	/// Returns the previous consecutive value before `self`.
	///
	/// Requires: the previous value is representable.
	func predecessor() -> RopeIndexType<ContentType> {
		if nodeContent == nil || nodeIndex == nil {
			println("fatal error: can not decrement start index")
			abort()
		} else if nodeIndex == nodeContent?.startIndex {
			let previousNodeIndex = findPreviousNodeIndex()
			
			if let previousIndex = previousNodeIndex {
				return previousIndex
			} else { // special marker, means nothing's before
				println("fatal error: can not decrement start index")
				abort()
			}
		} else {
			let previousInContent = nodeIndex?.predecessor()
			
			return RopeIndexType<ContentType>(nodePath: nodePath, nodeContent: nodeContent, nodeIndex: previousInContent)
		}
	}
}

func startIndexFor<ContentType : CollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType>(root: ViRopeNode<ContentType>) -> RopeIndexType<ContentType> {
	if root.childContent.isEmpty {
		// We're an empty string because we have no children.
		return RopeIndexType(nodePath: [], nodeContent: nil, nodeIndex: nil)
	} else {
		var nodeIndex = root.childContent.startIndex
		while nodeIndex != root.childContent.endIndex &&
			root.childContent[nodeIndex].startIndex == root.childContent[nodeIndex].endIndex {
				nodeIndex += 1
		}
		
		if nodeIndex == root.childContent.endIndex {
			// We're an empty string because our children are empty, not because we have no children.
			return RopeIndexType(nodePath: [], nodeContent: nil, nodeIndex: nil)
		} else {
			let firstText = root.childContent[nodeIndex]
			
			return RopeIndexType<ContentType>(
				nodePath: [(root, .ContentIndex(item: nodeIndex))],
				nodeContent: firstText,
				nodeIndex: firstText.startIndex)
		}
	}
}

func endIndexFor<ContentType : CollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType>(root: ViRopeNode<ContentType>) -> RopeIndexType<ContentType> {
	if root.childContent.isEmpty {
		// We're an empty string because we have no children.
		return RopeIndexType(nodePath: [], nodeContent: nil, nodeIndex: nil)
	} else {
		var nodeIndex = root.childContent.endIndex
		do {
			nodeIndex -= 1
		} while nodeIndex != root.childContent.startIndex &&
			root.childContent[nodeIndex].startIndex == root.childContent[nodeIndex].endIndex
		
		if (nodeIndex == root.childContent.startIndex &&
			root.childContent[nodeIndex].startIndex == root.childContent[nodeIndex].endIndex) {
				// We're an empty string because our children are empty, not because we have no children.
				return RopeIndexType(nodePath: [], nodeContent: nil, nodeIndex: nil)
		} else {
			let lastText = root.childContent[nodeIndex]
			
			return RopeIndexType(
				nodePath: [(root, .ContentIndex(item: nodeIndex))],
				nodeContent: lastText,
				nodeIndex: lastText.endIndex)
		}
	}
}

internal class ViRopeNode<ContentType : CollectionType> {
	
	let children: [ViRopeNode]
	let childContent: [ContentType]
	
	private let childLengths: LazyRandomAccessCollection<[Int]>
	private let childContentLengths: LazyRandomAccessCollection<[ContentType.Index.Distance]>
	
	private var length: Int {
		get {
			if children.isEmpty {
				return reduce(childContentLengths, 0, { (totalLength, contentLength) -> Int in
					totalLength + Int(contentLength.toIntMax())
				})
			} else {
				return reduce(childLengths, 0, { (totalLength, childLength) -> Int in
					totalLength + childLength
				})
			}
		}
	}
	
	init(children: [ViRopeNode]) {
		self.children = children
		childContent = []
		
		childLengths = lazy(children.map { $0.length })
		childContentLengths = lazy([])
	}
	
	init(childContent: [ContentType]) {
		self.childContent = childContent
		children = []
		
		childLengths = lazy([])
		childContentLengths = lazy(childContent.map { countElements($0) })
	}
}

// Fetches the index of childContent at which the provided global rope index will be found, given a starting offset that tells us where the provided leafNode is within the broader rope.
func helperChildIndexForIntegerIndexInNodeContent<ContentType : CollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType>(leafNode: ViRopeNode<ContentType>, requestedIndex: Int, startingOffset: Int) -> (Int, Int) {
	let start: (Int, Int, Bool) = (startingOffset, 0, false)
	
	let (offsetAtIndex: Int, index: Int, _) = leafNode.childContent.reduce(start, combine: { (reduceState, entry) -> (Int, Int, Bool) in
		let (offset, latestIndex, done) = reduceState
		
		if (done) {
			return reduceState
		}
		
		let lengthAtIndex = Int(leafNode.childContentLengths[latestIndex].toIntMax())
		
		if offset + lengthAtIndex > requestedIndex {
			return (offset, latestIndex, true)
		} else {
			return (offset + lengthAtIndex, latestIndex + 1, false)
		}
	})
	
	return (offsetAtIndex, index)
}

// Specifically fetches the content element at the given overall rope index once we are at the correct leaf node.
private func helperContentForIntegerIndexInNodeContent<ContentType : CollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType>(leafNode: ViRopeNode<ContentType>, index: Int, startingOffset: Int) -> ContentType._Element {
	let (offsetAtIndex, childContentIndex) = helperChildIndexForIntegerIndexInNodeContent(leafNode, index, startingOffset)
	let contentItem = leafNode.childContent[childContentIndex]
	let remainingOffset = index - offsetAtIndex
	
	if contentItem.startIndex is Int {
		return contentItem[remainingOffset as ContentType.Index]
	} else {
		var actualIndex = contentItem.startIndex
		for _ in 0...remainingOffset {
			actualIndex = actualIndex.successor()
		}
		
		return contentItem[actualIndex]
	}
}

// Fetches the index of children at which the provided global rope index will be found, given a starting offset that tells us where the provided rootNode is within the broader rope.
func helperChildIndexForIntegerIndexInTree<ContentType : CollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType>(startingNode: ViRopeNode<ContentType>, requestedIndex: Int, startingOffset: Int) -> (Int, Int) {
	let start: (Int, Int, Bool) = (startingOffset, 0, false)
	
	let (offsetAtIndex: Int, index: Int, _) = startingNode.children.reduce(start, combine: { (reduceState, entry) -> (Int, Int, Bool) in
		let (offset, latestIndex, done) = reduceState
		
		if (done) {
			return reduceState
		}
		
		let lengthAtIndex = startingNode.childLengths[latestIndex]
		
		if offset + lengthAtIndex > requestedIndex {
			return (offset, latestIndex, true)
		} else {
			return (offset + lengthAtIndex, latestIndex + 1, false)
		}
	})
	
	return (offsetAtIndex, index)
}

// Specifically fetches the content element at the given overall rope index when we are at a non-leaf node.
private func helperContentForIntegerIndexInTree<ContentType : CollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType>(startingNode: ViRopeNode<ContentType>, index: Int, startingOffset: Int) -> ContentType._Element {
	let (offsetAtIndex, childIndex) = helperChildIndexForIntegerIndexInTree(startingNode, index, startingOffset)
	let node = startingNode.children[childIndex]
	
	return contentForIntegerIndexInTree(node, index, offsetAtIndex)
}

// Fetches the content element at the given overall rope index provided the offset we are at so far; dispatch function to either look in child nodes or child content.
private func contentForIntegerIndexInTree<ContentType : CollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType>(startingNode: ViRopeNode<ContentType>, index: Int, startingOffset: Int) -> ContentType._Element {
	if startingNode.children.isEmpty {
		return helperContentForIntegerIndexInNodeContent(startingNode, index, startingOffset)
	} else {
		return helperContentForIntegerIndexInTree(startingNode, index, startingOffset)
	}
}

internal func contentForIntegerIndexInTree<ContentType : CollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType>(rootNode: ViRopeNode<ContentType>, index: Int) -> ContentType._Element {
	return contentForIntegerIndexInTree(rootNode, index, 0)
}

class ViRope {
	
	internal let root: ViRopeNode<String>
	internal let nodeIndices: [Range<Index>] = []
	
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
			if index.nodeIndex != nil && index.nodeContent != nil {
				// oh for comprehension, where art thou
				return index.nodeContent![index.nodeIndex!]
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
		nodeIndices = [Range(start: startIndex, end: endIndex)]
	}
	private init(updatedNodes: [String], indices: [Range<ViRope.Index>]) {
		root = ViRopeNode(childContent: updatedNodes)
		nodeIndices = indices
	}
	init() {
		root = ViRopeNode(childContent: [])
	}
	
	func append(string: String) -> ViRope {
		if let lastNode = root.childContent.last {
			let range = Range(start: startIndex, end: endIndex)
			return ViRope(updatedNodes: root.childContent + [string], indices: [range])
		} else {
			return ViRope(updatedNodes: [string], indices: [Range(start: startIndex, end: endIndex)])
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
		
		return ViRope(updatedNodes: updatedNodes, indices: [Range(start: startIndex, end: endIndex)]);
	}
	
	// FIXME make this use countElements instead
	func length() -> Int {
		return root.childContent.reduce(0, combine: { $0 + countElements($1) })
	}
	
	func toString() -> String {
		return join("", root.childContent)
	}
}