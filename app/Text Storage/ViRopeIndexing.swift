//
//  ViRopeIndexing.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 11/24/14.
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
