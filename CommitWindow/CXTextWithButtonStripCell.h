//
//  CXTextWithButtonStripCell.m
//  NSCell supporting row action buttons aligned to one side of a text table column.
//
//  Created by Chris Thomas on 2006-10-11.
//  Copyright 2006 Chris Thomas. All rights reserved.
//

@interface CXTextWithButtonStripCell : NSTextFieldCell
{
	// buttons contains a set of button definitions to draw at the right (or left) side of the cell.
	//
	// Each item is a dictionary with the following entries:
	//	• either @"title" NSString -- localized name of button
	//	  OR @"icon" 	-- NSImage -- icon
	//	• @"menu"		-- NSMenu -- if present, indicates that this button is a menu button
	//	• @"invocation"	-- NSInvocation -- required if this is a push button, useless for menu buttons
	//
	NSMutableArray *	fButtons;
	NSUInteger			fButtonPressedIndex;
	float				fButtonStripWidth;
	BOOL				fRightToLeft;
	
}

- (NSArray *)buttonDefinitions;
- (void)setButtonDefinitions:(NSArray *)newButtonDefinitions;

@end
