#import <CoreGraphics/CoreGraphics.h>
#import <GraphicsServices/GraphicsServices.h>
#import "EBookView.h"
#import "BooksDefaultsController.h"

@interface NSObject (HeartbeatDelegate)

- (void)heartbeatCallback:(id)ignored;

@end


@implementation EBookView

- (id)initWithFrame:(struct CGRect)rect
{
  [super initWithFrame:rect];
  //  tapinfo = [[UIViewTapInfo alloc] initWithDelegate:self view:self];

  size = 16.0f;

  path = @"";

  [self setEditable:NO];
  
  [self setTextSize:size];
  [self setTextFont:@"TimesNewRoman"];

  [self setAllowsRubberBanding:YES];
  [self setBottomBufferHeight:0.0f];

  [self scrollToMakeCaretVisible:NO];

  [self setScrollDecelerationFactor:0.995f];
  //  NSLog(@"scroll deceleration:%f\n", self->_scrollDecelerationFactor);
  [self setTapDelegate:self];
  [self setScrollerIndicatorsPinToContent:NO];
  lastVisibleRect = [self visibleRect];
  return self;
}

- (void)heartbeatCallback:(id)unused
{
  if ((![self isScrolling]) && (![self isDecelerating]))
    lastVisibleRect = [self visibleRect];
  if (_heartbeatDelegate != nil) {
    if ([_heartbeatDelegate respondsToSelector:@selector(heartbeatCallback:)]) {
      [_heartbeatDelegate heartbeatCallback:self];
    } else {
      [NSException raise:NSInternalInconsistencyException
		   format:@"Delegate doesn't respond to selector"];
    }
  }
}

- (void)setHeartbeatDelegate:(id)delegate
{
  _heartbeatDelegate = delegate;
  [self startHeartbeat:@selector(heartbeatCallback:) inRunLoopMode:nil];
}

- (void)hideNavbars
{
  if (_heartbeatDelegate != nil) {
    if ([_heartbeatDelegate respondsToSelector:@selector(hideNavbars)]) {
      [_heartbeatDelegate hideNavbars];
    } else {
      [NSException raise:NSInternalInconsistencyException
		   format:@"Delegate doesn't respond to selector"];
    }
  }
}

- (void)toggleNavbars
{
  if (_heartbeatDelegate != nil) {
    if ([_heartbeatDelegate respondsToSelector:@selector(toggleNavbars)]) {
      [_heartbeatDelegate toggleNavbars];
    } else {
      [NSException raise:NSInternalInconsistencyException
		   format:@"Delegate doesn't respond to selector"];
    }
  }
}

- (void)loadBookWithPath:(NSString *)thePath
{
  BOOL junk;
  return [self loadBookWithPath:thePath numCharacters:-1 didLoadAll:&junk];
}

- (void)loadBookWithPath:(NSString *)thePath numCharacters:(int)numChars
{
  BOOL junk;
  return [self loadBookWithPath:thePath numCharacters:numChars
	       didLoadAll:&junk];
}

- (void)loadBookWithPath:(NSString *)thePath numCharacters:(int)numChars
	      didLoadAll:(BOOL *)didLoadAll
{
  NSString *theHTML = nil;
  path = [[thePath copy] retain];
  if ([[[thePath pathExtension] lowercaseString] isEqualToString:@"txt"])
    {
      theHTML = [self HTMLFromTextFile:thePath];
    }
  else if ([[[thePath pathExtension] lowercaseString] isEqualToString:@"html"] ||
	   [[[thePath pathExtension] lowercaseString] isEqualToString:@"htm"])
    { 
      theHTML = [self HTMLFileWithoutImages:thePath];
    }
  if ((-1 == numChars) || (numChars >= [theHTML length]))
    {
      *didLoadAll = YES;
      [self setHTML:theHTML];
    }
  else
    {
      NSString *tempyString = [NSString stringWithFormat:@"%@</body></html>",
			       [theHTML HTMLsubstringToIndex:numChars didLoadAll:didLoadAll]];
      [self setHTML:tempyString];
    }
}

- (NSString *)HTMLFileWithoutImages:(NSString *)thePath
{
  BooksDefaultsController *defaults = [[BooksDefaultsController alloc] init];
  NSStringEncoding encoding = [defaults defaultTextEncoding];
  NSMutableString *originalText;
  NSString *outputHTML;
  NSLog(@"Checking encoding...");
  if (AUTOMATIC_ENCODING == encoding)
    {
      originalText = [[NSMutableString alloc]
		       initWithContentsOfFile:thePath
		       usedEncoding:&encoding
		       error:NULL];
      NSLog(@"Encoding: %d",encoding);
      if (nil == originalText)
	{
	  NSLog(@"Trying UTF-8 encoding...");
	  originalText = [[NSMutableString alloc]
			   initWithContentsOfFile:thePath
			   encoding: NSUTF8StringEncoding
			   error:NULL];
	}
      if (nil == originalText)
	{
	  NSLog(@"Trying ISO Latin-1 encoding...");
	  originalText = [[NSMutableString alloc]
			   initWithContentsOfFile:thePath
			   encoding: NSISOLatin1StringEncoding
			   error:NULL];
	}
      if (nil == originalText)
	{
	  NSLog(@"Trying Mac OS Roman encoding...");
	  originalText = [[NSMutableString alloc]
			   initWithContentsOfFile:thePath
			   encoding: NSMacOSRomanStringEncoding
			   error:NULL];
	}
      if (nil == originalText)
	{
	  NSLog(@"Trying ASCII encoding...");
	  originalText = [[NSMutableString alloc] 
			   initWithContentsOfFile:thePath
			   encoding: NSASCIIStringEncoding
			   error:NULL];
	}
      if (nil == originalText)
	{
	  originalText = [[NSMutableString alloc] initWithString:@"<html><body><p>Could not determine text encoding.  Try changing the default encoding in Preferences.</p></body></html>\n"];
	}
    }
  else // if encoding is specified
    {
      originalText = [[NSMutableString alloc]
		       initWithContentsOfFile:thePath
		       encoding: encoding
		       error:NULL];
      if (nil == originalText)
	{
	  originalText = [[NSMutableString alloc] initWithString:@"<html><body><p>Incorrect text encoding.  Try changing the default encoding in Preferences.</p></body></html>\n"];
	}
    } //else

  NSRange fullRange = NSMakeRange(0, [originalText length]);

  unsigned int i;

  //Comment out all images.
  i = [originalText replaceOccurrencesOfString:@"<img" withString:@"<!img"
		    options:NSLiteralSearch range:fullRange];
  NSLog(@"Commented out %d images.\n", i);
  fullRange = NSMakeRange(0, [originalText length]);
  i = [originalText replaceOccurrencesOfString:@"width=\"" withString:@"wodth=\"" options:NSLiteralSearch range:fullRange];
  i = [originalText replaceOccurrencesOfString:@"style=\"width:" withString:@"style=\"wodth:" options:NSLiteralSearch range:fullRange];
  NSLog(@"Removed %d width style tags.\n", i);
  i = [originalText replaceOccurrencesOfString:@"</body>" withString:@"<br /></body>" options:NSLiteralSearch range:fullRange];
  i = [originalText replaceOccurrencesOfString:@"</BODY>" withString:@"<br /></BODY>" options:NSLiteralSearch range:fullRange];
  outputHTML = [NSString stringWithString:originalText];
  [originalText release];

  //  struct CGSize asize = [outputHTML sizeWithStyle:nil forWidth:320.0];
  //  NSLog(@"Size for text: width: %f height: %f", asize.width, asize.height);
  return outputHTML;
}

- (NSString *)currentPath;
{
  return path;
}

- (void)embiggenText
  // "A noble spirit embiggens the smallest man." -- Jebediah Springfield
{
  if (size < 36.0f)
    {
      struct CGRect oldRect = [self visibleRect];
      NSLog(@"size: %f y: %f\n", size, oldRect.origin.y);
      float middleRect = oldRect.origin.y + (oldRect.size.height / 2);
      float scrollFactor = (size + 3)/size;  
      size += 2.0f;
      middleRect *= scrollFactor;
      oldRect.origin.y = middleRect - (oldRect.size.height / 2);
      NSLog(@"size: %f y: %f\n", size, oldRect.origin.y);
      [self setTextSize:size];
      [self loadBookWithPath:path];
      [self scrollPointVisibleAtTopLeft:oldRect.origin animated:YES];
      [self setNeedsDisplay];
    }
}

- (void)ensmallenText
  // "What the f--- does ensmallen mean?" -- Zach Brewster-Geisz
{
  if (size > 10.0f)
    {
      struct CGRect oldRect = [self visibleRect];
      float middleRect = oldRect.origin.y + (oldRect.size.height / 2);
      float scrollFactor = (size - 3)/size;
      size -= 2.0f;
      middleRect *= scrollFactor;
      oldRect.origin.y = middleRect - (oldRect.size.height / 2);
      [self setTextSize:size];
      [self loadBookWithPath:path]; // This is horribly slow!  Is there a better way?
      [self scrollPointVisibleAtTopLeft:oldRect.origin animated:YES];
      [self setNeedsDisplay];
    }
}
// None of these tap methods work yet.  They may never work.

- (void)handleDoubleTapEvent:(struct __GSEvent *)event
{
  [self embiggenText];
  //[super handleDoubleTapEvent:event];
}

- (void)handleSingleTapEvent:(struct __GSEvent *)event
{
  [self ensmallenText];
  //[super handleDoubleTapEvent:event];
}

- (void)mouseUp:(struct __GSEvent *)event
{
  /*************
   * NOTE: THE GSEVENTGETLOCATIONINWINDOW INVOCATION
   * WILL NOT COMPILE UNLESS YOU HAVE PATCHED GRAPHICSSERVICES.H TO ALLOW IT!
   * A patch is included in the svn.
  *****************/

  struct CGRect clicked = GSEventGetLocationInWindow(event);
  struct CGRect newRect = [self visibleRect];
  struct CGRect topTapRect = CGRectMake(0, 0, 320, 48);
  struct CGRect contentRect = [UIHardware fullScreenApplicationContentRect];
  struct CGRect botTapRect = CGRectMake(0, contentRect.size.height - 48, contentRect.size.width, 48);
  if ([self isScrolling])
    {
      BooksDefaultsController *defaults = [[BooksDefaultsController alloc] init];
      if (CGRectContainsPoint(topTapRect, clicked.origin))
	{
	  //scroll back one screen...
	  [self pageUpWithTopBar:NO bottomBar:![defaults toolbar]];
	}
      else if (CGRectContainsPoint(botTapRect,clicked.origin))
	{
	  //scroll forward one screen...
	  [self pageDownWithTopBar:![defaults navbar] bottomBar:NO];
	}
      else if (CGRectEqualToRect(lastVisibleRect, newRect))
	{  // If the old rect equals the new, then we must not be scrolling
	  [self toggleNavbars];
	}
      else
	{ //we are, in fact, scrolling
	  [self hideNavbars];
	}
      [defaults release];
    }
  BOOL unused = [self releaseRubberBandIfNecessary];
  lastVisibleRect = [self visibleRect];
  [super mouseUp:event];
}

// These two are so the toolbar buttons work!
// BUT: The the amount of the scroll needs to be adjusted based on the
// the defaults for showing the NAVBAR and TOOLBAR.
// Right now it scrolls based on full screen and thus, to far. Zach?
// FIXED: I think.
// TODO: Adjust the bottom and top buffers.  The scrolling works, but
// the text can wind up behind the toolbars at the bottom & top
// of the text.
- (void)pageDownWithTopBar:(BOOL)hasTopBar bottomBar:(BOOL)hasBotBar
{
  struct CGRect contentRect = [UIHardware fullScreenApplicationContentRect];
  float  scrollness = contentRect.size.height;
  scrollness -= (((hasTopBar) ? 48 : 0) + ((hasBotBar) ? 48 : 0));
  scrollness /= size;
  scrollness = floor(scrollness - 1.0f);
  scrollness *= size;
  // That little dance above was so we only scroll in
  // multiples of the text size.  And it doesn't even work!
  [self scrollByDelta:CGSizeMake(0, scrollness)	animated:YES];
  [self hideNavbars];
}

-(void)pageUpWithTopBar:(BOOL)hasTopBar bottomBar:(BOOL)hasBotBar
{
  struct CGRect contentRect = [UIHardware fullScreenApplicationContentRect];
  float  scrollness = contentRect.size.height;
  scrollness -= (((hasTopBar) ? 48 : 0) + ((hasBotBar) ? 48 : 0));
  scrollness /= size;
  scrollness = floor(scrollness - 1.0f);
  scrollness *= size;
  // That little dance above was so we only scroll in
  // multiples of the text size.  And it doesn't even work!
  [self scrollByDelta:CGSizeMake(0, -scrollness) animated:YES];
  [self hideNavbars];
}

- (int)textSize
  // This method is needed because the toolchain doesn't
  // currently handle floating-point return values in an
  // ARM-friendly way.
{
  return (int)size;
}

- (void)setTextSize:(int)newSize
{
  size = (float)newSize;
  [super setTextSize:size];
}

- (NSString *)HTMLFromTextFile:(NSString *)file
{
  BooksDefaultsController *defaults = [[BooksDefaultsController alloc] init];
  NSStringEncoding encoding = [defaults defaultTextEncoding];
  NSString *header = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 3.2//EN\">\n<html>\n\n<head>\n<title></title>\n</head>\n\n<body>\n<p>\n";
  NSString *outputHTML;
  NSMutableString *originalText;
  if (AUTOMATIC_ENCODING == encoding)
    {
      NSLog(@"Trying to determine encoding...");
      originalText = [[NSMutableString alloc] 
		       initWithContentsOfFile:file
		       usedEncoding:&encoding
		       error:NULL];
      NSLog(@"Found encoding: %d", encoding);

      if (nil == originalText)
	{
	  NSLog(@"Checking UTF-8 encoding...");
	  originalText = [[NSMutableString alloc]
			   initWithContentsOfFile:file
			   encoding:NSUTF8StringEncoding error:NULL];
	}
      if (nil == originalText)
	{
	  NSLog(@"Checking ISO Latin-1 encoding...");
	  originalText = [[NSMutableString alloc]
			   initWithContentsOfFile:file
			   encoding:NSISOLatin1StringEncoding error:NULL];
	}
      if (nil == originalText)
	{
	  NSLog(@"Checking Windows Latin-1 encoding...");
	  originalText = [[NSMutableString alloc]
			   initWithContentsOfFile:file
			   encoding:NSWindowsCP1252StringEncoding error:NULL];
	}
      if (nil == originalText)
	{
	  NSLog(@"Checking Mac OS Roman encoding...");
	  originalText = [[NSMutableString alloc]
			   initWithContentsOfFile:file
			   encoding:NSMacOSRomanStringEncoding error:NULL];
	}
      if (nil == originalText)
	{
	  NSLog(@"Checking ASCII encoding...");
	  originalText = [[NSMutableString alloc]
			   initWithContentsOfFile:file
			   encoding:NSASCIIStringEncoding error:NULL];
	}
      if (nil == originalText)
	{
	  originalText = [[NSMutableString alloc] initWithString:@"Could not determine text encoding.  Try changing the text encoding settings in Preferences.\n\n"];
	}
    }
  else //encoding is user-specified
    {
      originalText = [[NSMutableString alloc]
		       initWithContentsOfFile:file
		       encoding:encoding error:NULL];
      if (nil == originalText)
	{
	  originalText = [[NSMutableString alloc] initWithString:@"Incorrect text encoding.  Try changing the text encoding settings in Preferences.\n\n"];
	}
    }

  NSRange fullRange = NSMakeRange(0, [originalText length]);

  unsigned int i,j;
  j=0;
  i = [originalText replaceOccurrencesOfString:@"&" withString:@"&amp;"
		    options:NSLiteralSearch range:fullRange];
  NSLog(@"replaced %d &s\n", i);
  j += i;
  fullRange = NSMakeRange(0, [originalText length]);
  i = [originalText replaceOccurrencesOfString:@"<" withString:@"&lt;"
		    options:NSLiteralSearch range:fullRange];
  NSLog(@"replaced %d <s\n", i);
  j += i;
  fullRange = NSMakeRange(0, [originalText length]);
  i = [originalText replaceOccurrencesOfString:@">" withString:@"&gt;"
		    options:NSLiteralSearch range:fullRange];
  NSLog(@"replaced %d >s\n", i);
  j += i;
  fullRange = NSMakeRange(0, [originalText length]);
  i = [originalText replaceOccurrencesOfString:@"  " withString:@"&nbsp; "
		    options:NSLiteralSearch range:fullRange];
  NSLog(@"replaced %d double-spaces\n", i);
  j += i;
  fullRange = NSMakeRange(0, [originalText length]);
  // Argh, bloody MS line breaks!  Change them to UNIX, then...
  i = [originalText replaceOccurrencesOfString:@"\r\n" withString:@"\n"
		    options:NSLiteralSearch range:fullRange];
  NSLog(@"replaced %d carriage return/newlines\n", i);
  j += i;
  fullRange = NSMakeRange(0, [originalText length]);

  /************** DEPRECATED.
  // Change UNIX newlines to <br> tags.
  i = [originalText replaceOccurrencesOfString:@"\n" withString:@"<br />\n"
		    options:NSLiteralSearch range:fullRange];
  NSLog(@"replaced %d newlines\n", i);
  j += i;
  fullRange = NSMakeRange(0, [originalText length]);
  // And just in case someone has a Classic MacOS textfile...
  i = [originalText replaceOccurrencesOfString:@"\r" withString:@"<br />\n"
		    options:NSLiteralSearch range:fullRange];
  NSLog(@"replaced %d carriage returns\n", i);
  j += i;
  */

  //Change double-newlines to </p><p>.
  i = [originalText replaceOccurrencesOfString:@"\n\n" withString:@"</p>\n<p>"
		    options:NSLiteralSearch range:fullRange];
  NSLog(@"replaced %d double-newlines\n", i);
  j += i;
  fullRange = NSMakeRange(0, [originalText length]);
  // And just in case someone has a Classic MacOS textfile...
  i = [originalText replaceOccurrencesOfString:@"\r\r" withString:@"</p>\n<p>"
		    options:NSLiteralSearch range:fullRange];
  NSLog(@"replaced %d double-carriage-returns\n", i);
  j += i;

  NSLog(@"Replaced %d characters in textfile %@.\n", j, file);
  outputHTML = [NSString stringWithFormat:@"%@%@\n</p><br /><br />\n</body>\n</html>\n", header, originalText];
  [originalText release];
  return outputHTML;
}

- (void)invertText:(BOOL)b
{
  if (b)
    {
      // makes the the view white text on black
      float backParts[4] = {0, 0, 0, 1};
      float textParts[4] = {1, 1, 1, 1};
      CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
      [self setBackgroundColor: CGColorCreate( colorSpace, backParts)];
      [self setTextColor: CGColorCreate( colorSpace, textParts)];
      [self setScrollerIndicatorStyle:2];
    } else {
      float backParts[4] = {1, 1, 1, 1};
      float textParts[4] = {0, 0, 0, 1};
      CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
      [self setBackgroundColor: CGColorCreate( colorSpace, backParts)];
      [self setTextColor: CGColorCreate( colorSpace, textParts)];
      [self setScrollerIndicatorStyle:0];
    }
  // This "loadBookWithPath" invocation is a kludge;
  // for some reason the display doesn't update correctly
  // without it, and we can't yet figure out how to fix it.
  struct CGRect oldRect = [self visibleRect];
  [self loadBookWithPath:path];
  [self scrollPointVisibleAtTopLeft:oldRect.origin];
  [self setNeedsDisplay];
}


- (void)dealloc
{
  //[tapinfo release];
  [path release];
  [super dealloc];
}

@end