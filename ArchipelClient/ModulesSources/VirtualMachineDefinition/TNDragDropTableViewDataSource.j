/*
 * TNDragDropTableViewDatasource.j
 *
 * Copyright (C) 2010 Antoine Mercadal <antoine.mercadal@inframonde.eu>
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

@import <Foundation/Foundation.j>
@import <AppKit/CPTableView.j>

@import <TNKit/TNTableViewDataSource.j>


var TNDragDropTypeIndex = @"TNDragDropTypeIndex";


@implementation TNDragDropTableViewDataSource: TNTableViewDataSource
{

}

// drag and drop
- (BOOL)tableView:(CPTableView)aTableView writeRowsWithIndexes:(CPIndexSet)aRowIndex toPasteboard:(CPPasteboard)aPastboard
{

    [aPastboard declareTypes:[TNDragDropTypeIndex] owner:self];
    [aPastboard setData:[CPKeyedArchiver archivedDataWithRootObject:aRowIndex] forType:TNDragDropTypeIndex];

    return YES;
}

- (CPDragOperation)tableView:(CPTableView)aTableView validateDrop:(id)info proposedRow:(CPInteger)aRow proposedDropOperation:(CPTableViewDropOperation)anOperation
{
    if ([info draggingSource] == aTableView)
    {
        [aTableView setDropRow:aRow dropOperation:CPTableViewDropAbove];
        return CPDragOperationMove;
    }
    return CPDragOperationNone;
}


- (BOOL)tableView:(CPTableView)aTableView acceptDrop:(id <CPDraggingInfo>)info row:(int)aRow dropOperation:(CPTableViewDropOperation)anOperation
{

    var aPastboard   = [info draggingPasteboard],
        encodedData  = [aPastboard dataForType:TNDragDropTypeIndex],
        sourceIndex  = [CPKeyedUnarchiver unarchiveObjectWithData:encodedData];

    if (anOperation == CPTableViewDropAbove)
    {

        var aboveCount = 0,
            object,
            removeIndex;

        var index = [sourceIndex lastIndex];

        while (index != CPNotFound)
        {
            if (index >= aRow)
            {
                removeIndex = index + aboveCount;
                aboveCount ++;
            }
            else
            {
                removeIndex = index;
                aRow --;
            }

            object = [self objectAtIndex:removeIndex];
            [self removeObjectAtIndex:removeIndex];
            [self insertObject:object atIndex:aRow];

            index = [sourceIndex indexLessThanIndex:index];
        }
        [[CPNotificationCenter defaultCenter] postNotificationName:@"TNVirtualMachineDefinitionControllerNotification" object:self];

    }

    return YES;
}


@end
