//
//  TestViRopeUtf16.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 11/22/14.
//
//

import Foundation
import XCTest

class TestViRopeUtf16: XCTestCase {
	func testRopeUtf16HasSameCharactersAsUtf16String() {
		let rope = ViRope("bam😍🐻📼")
		let ropeString = rope.toString().utf16
		let utf16 = rope.utf16
		
		var stringIndex = ropeString.startIndex
		var utf16Index = utf16.startIndex
		while (stringIndex != ropeString.endIndex) {
			XCTAssertEqual(ropeString[stringIndex], utf16[utf16Index], "every rope UTF16 index should correspond to the right string UTF16 index");
			
			stringIndex = stringIndex.successor()
			utf16Index = utf16Index.successor()
		}
	}
	
	func testRopeUtf16ByIndexHasSameCharactersAsUtf16String() {
		let rope = ViRope("bam😍🐻📼").append("chabooyan").append("swizzle")
		let ropeString = rope.toString().utf16
		let utf16 = rope.utf16
		
		var index = 0
		while (index < countElements(ropeString)) {
			let thingie = utf16[index]
			XCTAssertEqual(ropeString[index], thingie, "every rope UTF16 int index should correspond to the right string UTF16 int index")
			
			index++
		}
	}
}