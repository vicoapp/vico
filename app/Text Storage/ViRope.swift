//
//  ViRope.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 11/1/14.
//
//

import Foundation

internal func integerIndexIntoContent<ContentType: CollectionType where ContentType.Index : ForwardIndexType>(content: ContentType, contentIndex: Int) -> ContentType._Element {
	if content.startIndex is Int {
		return content[contentIndex as ContentType.Index]
	} else {
		var index = content.startIndex
		for _ in 0...contentIndex {
			index = index.successor()
		}
		
		return content[advance(content.startIndex, contentIndex)]
	}
}

internal let defaultRopeBranchingFactorBits: UInt = 5
internal let defaultRopeLeafLengthBits: UInt = 12

/**
 * A rope/vector trie/gap buffer hybrid. Behaves mostly like a vector trie
 * a-la-clojure.core.PersistentVector, but the last level is an element of
 * `ContentType` (typically a Swift String) with up to `leafLength` in its
 * contents. As such, the last `log2(leafLength)` bits of an integer index
 * are indexed into the `ContentType` rather than the tree structure.
 *
 * If a branching factor and leaf length aren't specified, we default to a
 * branching factor of 32 and a leaf length of 4096.
 *
 * Currently the design is specifically for Strings as a backing store for
 * an editor. The intent is to have a shallow tree and to have the performance
 * of a single string as much as possible when dealing with smaller files,
 * while reaping the benefits of structural sharing and such when editing
 * larger files.
 *
 * ViStringRope provides convenience constructors/helpers and String/NSString
 * API bridging for the String use case.
 */
class ViRope<ContentType : ExtensibleCollectionType where ContentType : Equatable, ContentType.Index : BidirectionalIndexType> {
	
	private let emptyContent: ()->ContentType
	private let contentLength: (ContentType)->Int
	
	// Number of bits usable to index the branch list of a node.
	private let branchingFactorBits: UInt
	// Number of bits usable to index the length of a leaf.
	private let leafLengthBits: UInt
	// Current max depth of the trie.
	private let depth: UInt
	
	// The root node for the left side of the rope.
	private let leftRoot: ViRopeNode<ContentType>
	// The offset from 0 in content length that the edit window starts at. This 
	// can be seen as the total length of the left side of the rope in terms of
	// `contentLength`.
	private let editOffset: UInt
	// The edit window, which is a single item of ContentType that is updated
	// when edits are smaller than `leafLength`. Edits longer than `leafLength`
	// will require updating the `leftRoot`, and the balance of the edit will
	// be let in the edit window.
	private let editWindow: ContentType
	// The offset from `editOffset` that the right side of the rope starts at.
	// This can be seen as the total length of the edit window in terms of
	// `contentLength`.
	private let rightOffset: UInt
	// The root node for the right side of the rope, which contains content after
	// the edit window.
	private let rightRoot: ViRopeNode<ContentType>
	
	/**
     * Creates an empty rope for the given `ContentType`. Provides a way to
	 * create an empty version of the content type via `emptyContent`, and a
	 * way to compute the length of a given instance of `ContentType` via
	 * `contentLength`.
	 *
	 * `contentLength` is provided so that, for example, if you are using a Swift
	 * String as `ContentType`, you can use `utf16Count` instead of
	 * `countElements` to measure the length of a given String. This makes the
	 * computation of when to branch/etc O(1) instead of O(n) as it would be with
	 * `countElements` on a Swift String.
     */
	convenience init(emptyContent: ()->ContentType, contentLength: (ContentType)->Int) {
		self.init(updatedNodes: [],
			emptyContent: emptyContent,
			contentLength: contentLength,
			branchingFactorBits: defaultRopeBranchingFactorBits,
			leafLengthBits: defaultRopeLeafLengthBits,
			depth: 0)
	}
	convenience init(_ initialContent: ContentType, emptyContent: ()->ContentType, contentLength: (ContentType)->Int) {
		self.init(initialContent,
			emptyContent: emptyContent,
			contentLength: contentLength,
			branchingFactorBits: defaultRopeBranchingFactorBits,
			leafLengthBits: defaultRopeLeafLengthBits,
			depth: 0)
	}
	convenience init(_ initialContent: ContentType, emptyContent: ()->ContentType, contentLength: (ContentType)->Int, branchingFactorBits: UInt, leafLengthBits: UInt, depth: UInt) {
		self.init(updatedNodes: [initialContent],
			emptyContent: emptyContent,
			contentLength: contentLength,
			branchingFactorBits: branchingFactorBits,
			leafLengthBits: leafLengthBits,
			depth: depth)
	}
	internal init(updatedNodes: [ContentType], emptyContent: ()->ContentType, contentLength: (ContentType)->Int, branchingFactorBits: UInt, leafLengthBits: UInt, depth: UInt) {
		leftRoot = ViRopeNode(childContent: updatedNodes)
		editOffset = UInt(leftRoot.length)
		editWindow = emptyContent()
		rightOffset = editOffset
		rightRoot = ViRopeNode(children: [])
		
		self.emptyContent = emptyContent
		self.contentLength = contentLength
		self.branchingFactorBits = branchingFactorBits
		self.leafLengthBits = leafLengthBits
		self.depth = depth
	}
	private init(leftRoot: ViRopeNode<ContentType>,
			   editOffset: UInt,
			   editWindow: ContentType,
			  rightOffset: UInt,
				rightRoot: ViRopeNode<ContentType>,
			 emptyContent: ()->ContentType,
		    contentLength: (ContentType)->Int,
	  branchingFactorBits: UInt,
		   leafLengthBits: UInt,
					depth: UInt) {
		self.leftRoot = leftRoot
		self.editOffset = editOffset
		self.editWindow = editWindow
		self.rightOffset = rightOffset
		self.rightRoot = rightRoot
		
		self.emptyContent = emptyContent
		self.contentLength = contentLength
		self.branchingFactorBits = branchingFactorBits
		self.leafLengthBits = leafLengthBits
		self.depth = depth
	}
	
	internal func parallelTree<NewContentType : CollectionType where NewContentType : Equatable, NewContentType.Index : BidirectionalIndexType>(childTransformer: (String)->ContentType, newEmptyContent: ()->NewContentType, newContentLength: (NewContentType)->Int) -> ViRope<NewContentType> {
		return ViRope<NewContentType>(emptyContent: newEmptyContent, contentLength: newContentLength)
	}
	
	/// A character position in a `ViRope`.
	typealias Index = RopeIndexType<ContentType>
	
	var startIndex: Index {
		get {
			return startIndexFor(leftRoot)
		}
	}
	var endIndex: Index {
		get {
			return endIndexFor(rightRoot)
		}
	}
	
	subscript(index: Index) -> ContentType._Element {
		get {
			if let indexValue = index.value {
				return indexValue
			} else {
				println("fatal error: Can't form a Character from an empty String")
				abort()
			}
		}
	}
	
	/**
     * Note, this is potentially slow! It will have to iterate up to 4096
	 * characters successively if it operates on Swift strings. If you want
	 * integer indexing you *probably* want .utf16[index] on ViStringRope, which
	 * will work in constant time once it arrives at the appropriate string
	 * node.
	 */
	subscript(integerIndex: Int) -> ContentType._Element {
		get {
			let trueIndex = UInt(integerIndex)
			
			if trueIndex > rightOffset {
				let rightIndex = trueIndex - rightOffset
				return rightRoot.getIndex(rightIndex,
					branchingFactorBits: branchingFactorBits,
					leafLengthBits: leafLengthBits,
					depth: depth)
			} else if trueIndex > editOffset {
				return integerIndexIntoContent(editWindow, trueIndex - editOffset)
			} else {
				return leftRoot.getIndex(trueIndex,
					branchingFactorBits: branchingFactorBits,
					leafLengthBits: leafLengthBits,
					depth: depth)
			}
		}
	}
	
	func replaceRange(range: Range<Int>, newContents withContents: ContentType) -> ViRope {
		// possibilities:
		//   start is in left root, end is in left root -> slice them out, update
		//       edit offset, stick contents into edit buffer/replace edit buffer 
		//       with contents, move things right of the edit into right tree,
		//		 try to give the edit window some stuff from end of left and
		//       beginning of right with new contents in the middle
		
		if range.startIndex > editOffset && range.endIndex < rightOffset {
			// update edit buffer only
			return updateEditBuffer(trueRange, newContents)
		} else if trueRange.startIndex > rightOffset {
			// do crazy handling for everything being right of edit window
			return self
		} else { // if trueRange.startIndex {
		//   start is in left root, end is in right root -> slice out left,
		//       update edit offset, stick contents into edit buffer/replace,
		//       slice out right
		//	 start is in right root, end is in right root -> update edit offset,
		//		 pull parts of right root that are left of start into left root,
		//       stick contents into edit buffer/replace, slice out remaining
		//       right bits
			return self
		}
	}
	
	private func updateEditBuffer(bufferRange: Range<Int>, newContents: ContentType) -> ViRope {
		
		let leftEnd = advance(editBuffer.startIndex, bufferRange.startIndex)
		let rightStart = advance(leftEnd, bufferRange.length)
		let updatedEditBuffer =
			editBuffer[editBuffer.startIndex...leftEnd] +
				newContents +
				editBuffer[rightEnd...editBuffer.endIndex]
		
		ViRope(leftRoot: leftRoot, editOffset: editOffset, editWindow: updatedEditBuffer, rightOffset: rightOffset + bufferRange.length, rightRoot: rightRoot, emptyContent: emptyContent, contentLength: contentLength, branchingFactorBits: branchingFactorBits, leafLengthBits: leafLengthBits, depth: depth)
	}
	
	func append(newContent: ContentType) -> ViRope {
		if let lastNode = leftRoot.childContent.last {
			let range = Range(start: startIndex, end: endIndex)
			return ViRope(updatedNodes: leftRoot.childContent + [newContent], emptyContent: emptyContent, contentLength: contentLength, branchingFactorBits: branchingFactorBits, leafLengthBits: leafLengthBits, depth: depth)
		} else {
			return ViRope(updatedNodes: [newContent], emptyContent: emptyContent, contentLength: contentLength, branchingFactorBits: branchingFactorBits, leafLengthBits: leafLengthBits, depth: depth)
		}
	}
	
	func insert(string: String, atIndex: Int) -> ViRope {
		/*let (_, updatedNodes) = leftRoot.childContent.reduce((0, []), combine: { (progressInfo, node) -> (Int,[String]) in
			let (latestIndex, nodesSoFar) = progressInfo
			let count = countElements(node)
			let endIndex = incrementIndex(latestIndex + count)
			
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
		})*/
		
		return self;
	}
	
	// FIXME make this use countElements instead
	func length() -> ContentType.Index.Distance {
		return leftRoot.childContent.reduce(0, combine: { $0 + countElements($1) })
	}
	
	func toString() -> ContentType {
		return join(emptyContent(), leftRoot.childContent)
	}
}