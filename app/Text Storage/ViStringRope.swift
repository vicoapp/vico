//
//  ViRopeMutation.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 11/24/14.
//
//

import Foundation

// Convenience rope for dealing with Swift Strings.
class ViStringRopeHelper<T> : ViRope<String> {
	
	init() {
		super.init(updatedNodes: [],
			emptyContent: { "" },
			contentLength: { $0.utf16Count },
			branchingFactorBits: defaultRopeBranchingFactorBits,
			leafLengthBits: defaultRopeLeafLengthBits,
			depth: 0)
	}
	init(_ initialString: String) {
		super.init(updatedNodes: [initialString],
			emptyContent: { "" },
			contentLength: { $0.utf16Count },
			branchingFactorBits: defaultRopeBranchingFactorBits,
			leafLengthBits: defaultRopeLeafLengthBits,
			depth: 0)
	}
}
typealias ViStringRope = ViStringRopeHelper<String>