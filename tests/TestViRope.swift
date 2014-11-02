//
//  TestViRope.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 11/1/14.
//
//

import Foundation
import XCTest

class TestViRope: XCTestCase {
	func testRopeCanBeCreated() {
		let rope = ViRope()
		
		XCTAssertEqual(rope.length(), 0, "empty rope should have length 0")
		
		let contentedRope = ViRope("boom")
		
		XCTAssertEqual(contentedRope.length(), 4, "non-empty rope should have correct length")
		XCTAssertEqual(contentedRope.toString(), "boom", "non-empty rope should have right value")
	}
	
	func testRopeIsImmutable() {
		let initialRope = ViRope()
		
		let appendedRope = initialRope.append("hello")
		
		XCTAssert(appendedRope !== initialRope, "rope appending should not return the same rope")
		XCTAssertEqual(appendedRope.length(), 5, "appended rope should have correct length")
		XCTAssertEqual(initialRope.length(), 0, "old rope should have unchanged length")
		XCTAssertEqual(appendedRope.toString(), "hello", "appended rope should contain correct string")
		
		let insertedRope = appendedRope.insert("rm", atIndex: 2)
		
		XCTAssert(insertedRope !== initialRope, "rope insertion should not return the same rope")
		XCTAssert(insertedRope !== appendedRope, "rope insertion should not return the initial rope")
		XCTAssertEqual(insertedRope.length(), 7, "inserted rope should have correct length")
		XCTAssertEqual(appendedRope.length(), 5, "initial rope should have unchanged length")
		XCTAssertEqual(initialRope.length(), 0, "appended rope should have unchanged length")
		
		XCTAssertEqual(insertedRope.toString(), "hermllo", "inserted rope should contain correct string")
	}
	
	func testRopeInsertionWorksCorrectly() {
		let initialRope = ViRope("This is a man who is lucky")
		
		let insertedRope = initialRope.insert("un", atIndex: 21)
		XCTAssertEqual(insertedRope.toString(), "This is a man who is unlucky", "inserted rope should contain correct string")
		
		let insertedRope2 = insertedRope.insert("re", atIndex: 23)
		XCTAssertEqual(insertedRope2.toString(), "This is a man who is unrelucky", "inserted rope should contain correct string")
		
		let insertedRope3 = insertedRope2.insert("wo", atIndex: 10)
		XCTAssertEqual(insertedRope3.toString(), "This is a woman who is unrelucky", "inserted rope should contain correct string")
	}
	
	func testRopeIndexWorksCorrectly() {
		let string = "This is a man who is lucky"
		let rope = ViRope("This is a man who is lucky")
		
		var stringIndex = string.startIndex
		var ropeIndex = rope.startIndex
		
		while (stringIndex != string.endIndex) {
			XCTAssertEqual(rope[ropeIndex], string[stringIndex], "every string index should correspond to the appropriate rope index")
			
			stringIndex = stringIndex.successor()
			ropeIndex = ropeIndex.successor()
		}
		
		XCTAssertEqual(ropeIndex, rope.endIndex, "the final rope index must be the same as the rope's reported endIndex")
	}
}