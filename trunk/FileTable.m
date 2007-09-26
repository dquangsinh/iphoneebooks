// FileTable.m, by Nate True and the NES.app team, 
// with additions by Zachary Brewster-Geisz

/*

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; version 2
 of the License.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/

#import <GraphicsServices/GraphicsServices.h>
#import "FileTable.h"

@implementation FileTable

- (int)swipe:(int)type withEvent:(struct __GSEvent *)event;
{
  if ((_allowDelete == YES) && ((4 == type) || (8 == type)))
      {
        CGPoint rect = GSEventGetLocationInWindow(event);
        CGPoint point = CGPointMake(rect.x, rect.y - 45);
        CGPoint offset = _startOffset; 
        NSLog(@"FileTable.swipe: %d %f, %f", type, point.x, point.y);

        point.x += offset.x;
        point.y += offset.y;
        int row = [ self rowAtPoint:point ];

        [ [ self visibleCellForRow:row column:0] 
           _showDeleteOrInsertion:YES 
           withDisclosure:NO
           animated:YES 
           isDelete:YES 
           andRemoveConfirmation:NO
        ];

    }
    return [ super swipe:type withEvent:event ];
}

- (void)allowDelete:(BOOL)allow {
    _allowDelete = allow;
}

@end

@implementation DeletableCell

- (void)removeControlWillHideRemoveConfirmation:(id)fp8
{
    [ self _showDeleteOrInsertion:NO
          withDisclosure:NO
          animated:YES
          isDelete:YES
          andRemoveConfirmation:YES
    ];
}

- (void)_willBeDeleted
{
  [[NSNotificationCenter defaultCenter] postNotificationName:SHOULDDELETEFILE object:self];
}

- (void)setTable:(FileTable *)table {
    _table = table;
}

- (void)setFiles:(NSMutableArray *)files {
    _files = files;
}

- (NSString *)path {
        return [[_path retain] autorelease];
}

- (void)setPath: (NSString *)path {
        [_path release];
        _path = [path copy];
}

@end

