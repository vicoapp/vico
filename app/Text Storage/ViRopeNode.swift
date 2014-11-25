//
//  ViRopeNode.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 11/24/14.
//
//

import Foundation

internal class ViRopeNode<ContentType : CollectionType> {
	
	let children: [ViRopeNode]
	let childContent: [ContentType]
	
	private let childLengths: LazyRandomAccessCollection<[Int]>
	private let childContentLengths: LazyRandomAccessCollection<[ContentType.Index.Distance]>
	
	internal var length: Int {
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
	
	func getIndex(integerIndex: UInt, branchingFactorBits: UInt, leafLengthBits: UInt, depth: UInt) -> ContentType._Element {
		if depth == 0 {
			return getContentIndex(Int(integerIndex & branchingFactorBits),
				contentIndex: Int(integerIndex >> branchingFactorBits & leafLengthBits))
		} else {
			let levelShifted = integerIndex >> (branchingFactorBits * depth)
			let childIndex = levelShifted & branchingFactorBits
			
			return children[Int(childIndex)].getIndex(integerIndex, branchingFactorBits: branchingFactorBits, leafLengthBits: leafLengthBits, depth: depth)
		}
	}
	
	private func getContentIndex(childContentIndex: Int, contentIndex: Int) -> ContentType._Element {
		let content = childContent[childContentIndex]
	
		return integerIndexIntoContent(content, contentIndex)
	}
}

// Fetches the index of childContent at which the provided global rope index will be found, given a starting offset that tells us where the provided leafNode is within the broader rope.
private func helperChildIndexForIntegerIndexInNodeContent<ContentType : CollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType>(leafNode: ViRopeNode<ContentType>, requestedIndex: Int, startingOffset: Int) -> (Int, Int) {
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
	
	return integerIndexIntoContent(contentItem, remainingOffset)
}

// Fetches the index of children at which the provided global rope index will be found, given a starting offset that tells us where the provided rootNode is within the broader rope.
private func helperChildIndexForIntegerIndexInTree<ContentType : CollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType>(startingNode: ViRopeNode<ContentType>, requestedIndex: Int, startingOffset: Int) -> (Int, Int) {
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
