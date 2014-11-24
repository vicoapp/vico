//
//  ViRopeUtf16.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 11/22/14.
//
//

import Foundation

public func ==(lhs: String.UTF16View, rhs: String.UTF16View) -> Bool {
	var leftIndex = lhs.startIndex
	var rightIndex = rhs.startIndex
	
	while (leftIndex != lhs.endIndex && rightIndex != rhs.endIndex) {
		if (lhs[leftIndex] != rhs[rightIndex]) {
			return false;
		}
		leftIndex = leftIndex.successor()
		rightIndex = rightIndex.successor()
	}
	
	return leftIndex != rightIndex;
}

extension String.UTF16View : Equatable {
	
}

extension ViRope {
	
	struct UTF16View : Sliceable {
		
		typealias SubSlice = UTF16View
		typealias Index = RopeIndexType<String.UTF16View>
		
		private let rootNode: ViRopeNode<String.UTF16View>
		private let range: Range<Index>
		
		var startIndex: Index {
			get {
				return range.startIndex
			}
		}
		var endIndex: Index {
			get {
				return range.endIndex
			}
		}
		
		subscript (bounds: Range<UTF16View.Index>) -> UTF16View {
			get {
				return UTF16View(rootNode: rootNode, range: bounds)
			}
		}

		subscript (position: UTF16View.Index) -> UTF16Char {
			get {
				// Oh dear. We unwrap it because no one should be building a UTF16View that will reach outside of the valid range.
				return position.value!
			}
		}
		
		subscript (position: Int) -> UTF16Char {
			get {
				return contentForIntegerIndexInTree(rootNode, position)
			}
		}
		
		func generate() -> IndexingGenerator<UTF16View> {
			return IndexingGenerator(self)
		}
	}
	
	private var utf16Root: ViRopeNode<String.UTF16View> {
		get {
			return ViRopeNode(childContent: self.root.childContent.map { $0.utf16 })
		}
	}
	
	var utf16: UTF16View {
		get {
			let root = utf16Root

			return UTF16View(rootNode: utf16Root, range: Range(start: startIndexFor(root), end: endIndexFor(root)))
		}
	}
	
	/*func characterAtIndex(index: Int) -> unichar {
	return utf16[index]
	}*/
}