/*
 * CPMenu+addItemWithImage.j
 *
 * Copyright (C) 2013 Cyril Peponnet <cyril@peponnet.fr>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

@import <AppKit/CPMenu.j>


/*! @ingroup categories
    add a custom addItemWithImage function
*/
@implementation CPMenu (addItemWithImage)

- (CPMenuItem)addItemWithImage:(CPString)aTitle action:(SEL)anAction keyEquivalent:(CPString)aKeyEquivalent imagePath:(CPString)aPath
{
	var image = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:aPath] size:CGSizeMake(12, 12)],
		item  = [[CPMenuItem alloc] initWithTitle:(@" " + aTitle) action:anAction keyEquivalent:aKeyEquivalent];

	[item setImage:image];

	[self insertItem:item atIndex:[_items count]];

	return item;

}

@end
