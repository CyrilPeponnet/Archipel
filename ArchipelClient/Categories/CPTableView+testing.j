@import <AppKit/CPTableView.j>


/*! @ingroup categories
    Make CPTabView border editable
*/
@implementation CPTableView (testing)

- (CPInteger)rowAtPoint:(CGPoint)aPoint
 {
  /*if (_implementedDelegateMethods & CPTableViewDelegate_tableView_heightOfRow_)
  {
  return [_cachedRowHeights indexOfObject:aPoint
  inSortedRange:nil
  options:0
  usingComparator:function(aPoint, rowCache)
  {
  var upperBound = rowCache.heightAboveRow;

  if (aPoint.y < upperBound)
  return CPOrderedAscending;

  if (aPoint.y > upperBound + rowCache.height + _intercellSpacing.height)
  return CPOrderedDescending;

  return CPOrderedSame;
  }];
  }*/

  var y = aPoint.y,
  row = FLOOR(y / (_rowHeight + _intercellSpacing.height));

  if (row >= _numberOfRows)
  {
  	CPLog.info("we juste going too far");
  	CPLog.info(CPNotFound);
	  return CPNotFound;

  }

  return row;
 }

@end
