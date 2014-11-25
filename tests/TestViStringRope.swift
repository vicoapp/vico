//
//  TestViStringRope
//  vico
//
//  Created by Antonio Salazar Cardozo on 11/1/14.
//
//

import Foundation
import XCTest

class TestViStringRope: XCTestCase {
	func testRopeCanBeCreated() {
		let rope = ViStringRope()
		let contentedRope = ViStringRope("boom")
		
		XCTAssertEqual(rope.length(), 0, "empty rope should have length 0")
		
		XCTAssertEqual(contentedRope.length(), 4, "non-empty rope should have correct length")
		XCTAssertEqual(contentedRope.toContent(), "boom", "non-empty rope should have right value")
	}
	
	func testRopeIsImmutable() {
		let initialRope = ViStringRope()
		let appendedRope = initialRope.append("hello")
		let insertedRope = appendedRope.insert("rm", atIndex: 2)
		
		XCTAssert(appendedRope !== initialRope, "rope appending should not return the same rope")
		XCTAssertEqual(appendedRope.length(), 5, "appended rope should have correct length")
		XCTAssertEqual(initialRope.length(), 0, "old rope should have unchanged length")
		XCTAssertEqual(appendedRope.toContent(), "hello", "appended rope should contain correct string")
		
		XCTAssert(insertedRope !== initialRope, "rope insertion should not return the same rope")
		XCTAssert(insertedRope !== appendedRope, "rope insertion should not return the initial rope")
		XCTAssertEqual(insertedRope.length(), 7, "inserted rope should have correct length")
		XCTAssertEqual(appendedRope.length(), 5, "initial rope should have unchanged length")
		XCTAssertEqual(initialRope.length(), 0, "appended rope should have unchanged length")
		
		XCTAssertEqual(insertedRope.toContent(), "hermllo", "inserted rope should contain correct string")
	}
	
	func testRopeInsertionWorksCorrectly() {
		let initialRope = ViStringRope().append("This is a man who is lucky")
		
		let insertedRope = initialRope.insert("un", atIndex: 21)
		let insertedRope2 = insertedRope.insert("re", atIndex: 23)
		let insertedRope3 = insertedRope2.insert("wo", atIndex: 10)
		
		XCTAssertEqual(insertedRope.toContent(), "This is a man who is unlucky", "inserted rope should contain correct string")
		
		XCTAssertEqual(insertedRope2.toContent(), "This is a man who is unrelucky", "inserted rope should contain correct string")
		
		XCTAssertEqual(insertedRope3.toContent(), "This is a woman who is unrelucky", "inserted rope should contain correct string")
	}
	
//	func testRopeIndexWorksCorrectlyOnEmptyString() {
//		let rope = ViStringRope("")
//		
//		XCTAssertEqual(rope.startIndex, rope.endIndex, "start and end indices should be equal in empty rope")
//	}
	
//	func testRopeIndexWorksCorrectlyOnSingleString() {
//		let string = "This is a man who is lucky"
//		let rope = ViStringRope("This is a man who is lucky")
//		
//		var stringIndex = string.startIndex
//		var ropeIndex = rope.startIndex
//		
//		while (stringIndex != string.endIndex) {
//			XCTAssertEqual(rope[ropeIndex], string[stringIndex], "every string index should correspond to the appropriate rope index forwards")
//			
//			stringIndex = stringIndex.successor()
//			ropeIndex = ropeIndex.successor()
//		}
//		
//		XCTAssertEqual(ropeIndex, rope.endIndex, "the final rope index must be the same as the rope's reported endIndex when moving forwards")
//		
//		do {
//			stringIndex = stringIndex.predecessor()
//			ropeIndex = ropeIndex.predecessor()
//
//			XCTAssertEqual(rope[ropeIndex], string[stringIndex], "every string index should correspond to the appropriate rope index backwards")
//		} while (stringIndex != string.startIndex)
//		
//		XCTAssertEqual(ropeIndex, rope.startIndex, "the final rope index must be the same as the rope's reported startIndex when moving backwards")
//
//	}
//	
//	func testRopeIndexWorksCorrectlyOnMultiStrings() {
//		let string = "This is a man who is lucky"
//		let secondString = "that he is alive"
//		let rope = ViStringRope("This is a man who is lucky").append(secondString)
//		
//		var stringIndex = string.startIndex
//		var ropeIndex = rope.startIndex
//		
//		while (stringIndex != string.endIndex) {
//			XCTAssertEqual(rope[ropeIndex], string[stringIndex], "every string index should correspond to the appropriate rope index forwards")
//			
//			stringIndex = stringIndex.successor()
//			ropeIndex = ropeIndex.successor()
//		}
//		
//		stringIndex = secondString.startIndex
//		while (stringIndex != secondString.endIndex) {
//			XCTAssertEqual(rope[ropeIndex], secondString[stringIndex], "every string index should correspond to the appropriate rope index forwards")
//			
//			stringIndex = stringIndex.successor()
//			ropeIndex = ropeIndex.successor()
//		}
//		
//		XCTAssertEqual(ropeIndex, rope.endIndex, "the final rope index must be the same as the rope's reported endIndex when moving forwards")
//		
//		do {
//			stringIndex = stringIndex.predecessor()
//			ropeIndex = ropeIndex.predecessor()
//			
//			XCTAssertEqual(rope[ropeIndex], secondString[stringIndex], "every string index should correspond to the appropriate rope index backwards")
//		} while (stringIndex != secondString.startIndex)
//		
//		stringIndex = string.endIndex
//		do {
//			stringIndex = stringIndex.predecessor()
//			ropeIndex = ropeIndex.predecessor()
//			
//			XCTAssertEqual(rope[ropeIndex], string[stringIndex], "every string index should correspond to the appropriate rope index backwards")
//		} while (stringIndex != string.startIndex)
//		
//		XCTAssertEqual(ropeIndex, rope.startIndex, "the final rope index must be the same as the rope's reported startIndex when moving backwards")
//	}
//	
//	func testRopeIndexWorksCorrectlyWithEmptyStringInsertions() {
//		let string = "This"
//		let secondString = "is"
//		let rope = ViStringRope(string).append("").append(secondString)
//		
//		var stringIndex = string.startIndex
//		var ropeIndex = rope.startIndex
//		
//		while (stringIndex != string.endIndex) {
//			XCTAssertEqual(rope[ropeIndex], string[stringIndex], "every string index should correspond to the appropriate rope index forwards")
//			
//			stringIndex = stringIndex.successor()
//			ropeIndex = ropeIndex.successor()
//		}
//		
//		stringIndex = secondString.startIndex
//		while (stringIndex != secondString.endIndex) {
//			XCTAssertEqual(rope[ropeIndex], secondString[stringIndex], "every string index should correspond to the appropriate rope index forwards")
//			
//			stringIndex = stringIndex.successor()
//			ropeIndex = ropeIndex.successor()
//		}
//		
//		XCTAssertEqual(ropeIndex, rope.endIndex, "the final rope index must be the same as the rope's reported endIndex when moving forwards")
//		
//		do {
//			stringIndex = stringIndex.predecessor()
//			ropeIndex = ropeIndex.predecessor()
//			
//			XCTAssertEqual(rope[ropeIndex], secondString[stringIndex], "every string index should correspond to the appropriate rope index backwards")
//		} while (stringIndex != secondString.startIndex)
//		
//		stringIndex = string.endIndex
//		do {
//			stringIndex = stringIndex.predecessor()
//			ropeIndex = ropeIndex.predecessor()
//			
//			XCTAssertEqual(rope[ropeIndex], string[stringIndex], "every string index should correspond to the appropriate rope index backwards")
//		} while (stringIndex != string.startIndex)
//		
//		XCTAssertEqual(ropeIndex, rope.startIndex, "the final rope index must be the same as the rope's reported startIndex when moving backwards")
//	}
//	
//	func testRopeIndexWorksCorrectlyWithEmptyStringsOnEnds() {
//		let string: String = "This"
//		let ropeWithEmptyStart = ViStringRope("").append(string)
//		
//		var stringIndex = string.startIndex
//		var ropeIndex = ropeWithEmptyStart.startIndex
//		
//		while (stringIndex != string.endIndex) {
//			XCTAssertEqual(ropeWithEmptyStart[ropeIndex], string[stringIndex], "every string index should correspond to the appropriate rope index forwards")
//			
//			stringIndex = stringIndex.successor()
//			ropeIndex = ropeIndex.successor()
//		}
//		
//		XCTAssertEqual(ropeIndex, ropeWithEmptyStart.endIndex, "even with an empty start string, the final rope index must be the same as the rope's reported endIndex when moving forwards")
//		
//		let ropeWithEmptyEnd = ViStringRope(string).append("")
//		
//		stringIndex = string.startIndex
//		ropeIndex = ropeWithEmptyEnd.startIndex
//		
//		while (stringIndex != string.endIndex) {
//			XCTAssertEqual(ropeWithEmptyEnd[ropeIndex], string[stringIndex], "every string index should correspond to the appropriate rope index forwards")
//			
//			stringIndex = stringIndex.successor()
//			ropeIndex = ropeIndex.successor()
//		}
//		
//		XCTAssertEqual(ropeIndex, ropeWithEmptyEnd.endIndex, "even with an empty end string, the final rope index must be the same as the rope's reported endIndex when moving forwards")
//	}
}