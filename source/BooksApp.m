/* ------ BooksApp, written by Zachary Brewster-Geisz
   (and others)
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

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIAlertSheet.h>
#import <UIKit/UIView-Geometry.h>
#import <UIKit/UIHardware.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UITextView.h>
#import <UIKit/UIView.h>
#import <UIKit/UIKeyboard.h>
#import <UIKit/UITransitionView.h>
#import <UIKit/UINavigationItem.h>
#import <UIKit/UINavBarButton.h>
#import <UIKit/UIFontChooser.h>
#import "EBookView.h"
#import "EBookImageView.h"
#import "FileBrowser.h"
#import "BooksDefaultsController.h"
#import "HideableNavBar.h"
#import "common.h"
#import "BoundsChangedNotification.h"

#import "BooksApp.h"
#import "PreferencesController.h"

#include <stdio.h>
#import "FileNavigationItem.h"

@implementation BooksApp
/**
 * Log all notifications.
 */
+ (void)debugNotification:(NSNotification*)p_note {
  GSLog(@"NOTIFICATION: %@", [p_note name]);
}
/*
   enum {
   kFACEUP = 0,
   kNORMAL = 1,
   kUPSIDEDOWN = 2,
   kLANDL = 3,
   kLANDR = 4,
   kFACEDOWN = 6
   };
   */
// Delegate methods
- (void)alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button 
{
	GSLog(@"%s .", _cmd);
	[sheet dismissAnimated:YES];
	if (1 == button)  //reset prefs
	{
		[defaults reset];
	}
	//reset the status as if the app had previously closed correctly
	[defaults setAppStatus:APPCLOSEDVALUE];
	//continue where we were before we opened the alert
	[self applicationDidFinishLaunching:nil];
}
- (void)alertCrashDetected
{
	GSLog(@"%s .", _cmd);
	GSLog(@"alertcrashdetected");
	NSString *bodyText = @"Prior crash detected, do you want to reset preferences";
	CGRect rect = [[UIWindow keyWindow] bounds];
	UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:CGRectMake(0,rect.size.height - 240, rect.size.width,240)];
	[alertSheet setTitle:@"Error opening books"];
	[alertSheet setBodyText:bodyText];
	[alertSheet addButtonWithTitle:@"YES"];
	[alertSheet addButtonWithTitle:@"NO"];
	[alertSheet setDelegate: self];
	[alertSheet popupAlertAnimated:YES];
}

/**
 * Hide the navbars before we rotate.
 */
- (void)boundsWillChange:(BoundsChangedNotification*)p_note {
  GSLog(@"BooksApp-boundsWillChange");
   
  // Hide the nav bars.
  [self hideNavbars];
  
  struct CGRect rect = [p_note newBounds];;
  struct CGRect frameRect = CGRectMake(rect.origin.x, rect.size.height, rect.size.width, TOOLBAR_HEIGHT);
  [bottomNavBar setFrame:frameRect];
  
  // Hide the slider.
  UIView *topView = [navBar topView];
  if([topView respondsToSelector:@selector(hideSlider)]) {
    EBookView *ebv = (EBookView*)topView;
    [ebv hideSlider];
  }
}

/**
 * Notification when our bounds change - we probably rotated.
 */
- (void)boundsDidChange:(BoundsChangedNotification*)p_note {
  GSLog(@"BooksApp-boundsDidChange");
  
  [defaults setUiOrientation:[p_note uiOrientationCode]];
  
  // Fix the transition view's size
  [m_transitionView setFrame:[p_note newBounds]];
  
  // Fix the position of the prefs button.
  struct CGSize newSize = [p_note newBounds].size;
  GSLog(@"Tweaking prefs button for width %f", newSize.width);
  float lMargin = 45.0f;
  [prefsButton retain];
  [prefsButton removeFromSuperview];
  [prefsButton setFrame:CGRectMake(newSize.width - lMargin, 9, 40, 30)];
  [navBar addSubview:prefsButton];
  [prefsButton release];
  
  //[navBar setTransform:[p_note transformation]];
  //[bottomNavBar setTransform:[p_note transformation]];
  
  //[self setupNavbar];
  //[self setupToolbar];
  
  [self hideNavbars];
  
  UIView *topView = [navBar topView];
  if([topView respondsToSelector:@selector(numberOfRowsInTable:)]) {
    // FIXME: This selector is a kludgey choice, but it works.
    [NSTimer scheduledTimerWithTimeInterval:0.2f target:navBar selector:@selector(show) userInfo:nil repeats:NO];
  }
  
  [self adjustStatusBarColorWithUiOrientation:[p_note uiOrientationCode]];
}

- (void)applicationDidFinishLaunching:(id)unused {  
  m_documentExtensions = [[NSArray arrayWithObjects:@"txt", @"htm", @"html", @"pdb", @"jpg", @"png", @"gif", nil] retain];
	
	//investigate using [self setUIOrientation 3] that may alleviate for the need of a weirdly sized window
	defaults = [BooksDefaultsController sharedBooksDefaultsController];
  [defaults setRotateLocked:[defaults isRotateLocked]];
	//bcc rect to change for rotate90
	NSString *lAppStatus = [defaults appStatus];
	GSLog(@"appstatus: %@", lAppStatus);
	if ([lAppStatus isEqualToString: APPOPENVALUE])
	{
		//bcc need error handling now.
		//should be able to revert to previously known to be ok prefs, lets just say we erase them
		[self alertCrashDetected];
	}
	//now set the app status to open
	[defaults setAppStatus:APPOPENVALUE];


	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateToolbar:)
												 name:TOOLBAR_DEFAULTS_CHANGED_NOTIFICATION
											   object:nil];

	window = [[UIWindow alloc] initWithContentRect:[UIHardware fullScreenApplicationContentRect]];  
  mainView = [[UIView alloc] initWithFrame:[window bounds]];
  [window setContentView:mainView];
  
  m_transitionView = [[UITransitionView alloc] initWithFrame:[window bounds]];
  [mainView addSubview:m_transitionView];
	[m_transitionView setDelegate:self];
  
  /*
   * We need to fix up any prefs-weirdness relating to file path before we try to open a document.
   * Figure out if we have a directory or a file and if it exists.  If it doesn't, jump back to the
   * default root and let them start over.
   */
  NSString *recentFile = [defaults lastBrowserPath];
  BOOL isDir = NO;
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:recentFile isDirectory:&isDir];
  
  readingText = exists && !isDir;
  
  if(!exists) {
    [defaults setLastBrowserPath:[BooksDefaultsController defaultEBookPath]];
    [defaults removePerFileDataForFile:recentFile];
    recentFile = [defaults lastBrowserPath];
  }
  
  NSString *defImage = [self _pathToDefaultImageNamed:[self nameOfDefaultImageToUpdateAtSuspension]];
  
  
  if(![[NSFileManager defaultManager] fileExistsAtPath:defImage]) {
    defImage = [[NSBundle mainBundle] pathForResource:@"Default" ofType:@"png"];
  }
  
  m_startupImage = [[EBookImageView alloc] initWithContentsOfFile:defImage
                                                   withFrame:[window bounds] 
                                                 scaleAspect:NO];
  [m_transitionView transition:0 toView:m_startupImage];

  // At this point, we're showing either the startup book or the cover image in the real imageView and m_startupView is gone.

  [self adjustStatusBarColorWithUiOrientation:-1];
  
  [window orderFront: self];
	[window makeKey: self];
	[window _setHidden: NO];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(boundsDidChange:)
                                               name:[BoundsChangedNotification didChangeName]
                                             object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(boundsWillChange:)
                                               name:[BoundsChangedNotification willChangeName]
                                             object:nil];
  
  // We need to get back to the main runloop for some things to finish up.  Schedule a timer to
  // fire almost immediately.
  [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(finishUpLaunch) userInfo:nil repeats:NO];
}

/**
 * This needs to be called once at startup.
 *
 * Should be called at the point where the next toolbar or view change needs
 * to trigger animation.  If readingText, call right before swtiching to the text view.
 * If not reading text call right before pushing the top-most path entry (even it it's the root).
 *
 * Clear as mud, right?
 */
- (void)transitionNavbarAnimation {
  [mainView addSubview:navBar];
  [mainView addSubview:bottomNavBar];

  [navBar enableAnimation];
}

/**
 * Store screen shot (if enabled), setup navigation bar, and start displaying the 
 * last read file.  Takes down splash image if it was present.
 */
- (void)finishUpLaunch {
	GSLog(@"%s .", _cmd);
  NSString *recentFile = [defaults lastBrowserPath];

  [self setupNavbar];
	[self setupToolbar];

  // Get last browser path and start loading files
	NSString *lastBrowserPath;
  if(readingText) {
    lastBrowserPath = [recentFile stringByDeletingLastPathComponent];
  } else {
    lastBrowserPath = [defaults lastBrowserPath];
  }
  
	NSMutableArray *arPathComponents = [[NSMutableArray alloc] init]; 
  
  [arPathComponents addObject:lastBrowserPath];
  lastBrowserPath = [lastBrowserPath stringByDeletingLastPathComponent]; // prime for loop
  
  NSString *stopAtPath = [[BooksDefaultsController defaultEBookPath] stringByDeletingLastPathComponent];
  while(![lastBrowserPath isEqualToString:stopAtPath] && ![lastBrowserPath isEqualToString:@"/"]) {
    [arPathComponents addObject:lastBrowserPath];
    lastBrowserPath = [lastBrowserPath stringByDeletingLastPathComponent];
  } // while
  
  // Loop over all the paths and add them to the nav bar.
  int pathCount = [arPathComponents count];
  for(pathCount = pathCount-1; pathCount >= 0 ; pathCount--) {    
    if(!readingText && pathCount == 0) {
      /*
       * We're not reading a book and we're on the last item.  We want animation on so the 
       * book image gets transitioned off.
       */
      [self transitionNavbarAnimation];
      [navBar setTransitionOffView:m_startupImage];
    }
    
    NSString *curPath = [arPathComponents objectAtIndex:pathCount];
    // Add the current path to the toolbar
    [self fileBrowser:nil fileSelected:curPath];
    
    // Need to show the navbar after the last transition if we're not reading.
    /*
    if(!readingText && pathCount == 0) {
      [navBar show];
    }
     */
  }
      
	if(readingText) {
    /*
     * If we are reading text, then we DIDN'T finish setting up the navbar during
     * the path-push process.  So we'd better do it now!
     */
    [self transitionNavbarAnimation];
    
    // Pushing the file onto the toolbar will trigger it being opened.
    [navBar setTransitionOffView:m_startupImage];
    UIView *view = [self showDocumentAtPath:recentFile];    
    FileNavigationItem *fni = [[FileNavigationItem alloc] initWithDocument:recentFile view:view];
    [navBar pushNavigationItem:fni];
    [fni release];
    
    // If reading, hide the nav bars (but they need to be added to the view first)
    /*
    [navBar hide];
    [bottomNavBar hide];
     */
  }
  
	[arPathComponents release];
  
  [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(applyOrientationLater) userInfo:nil repeats:NO];
}

/**
 * Apply the app rotation at startup - but we need to do it from the main thread after a runloop.
 */
- (void)applyOrientationLater {
  [self setUIOrientation:[defaults uiOrientation]];
}

/**
 * Need to cleanup after the first transition is done.
 *
 * This is called from the deferred transition code in HideableNavBar.  We need this
 * object to stay alive long enough for the book to finish loading (which is async) and
 * for the final transition to complete.
 */
- (void)cleanupStartupImage {
  [m_startupImage removeFromSuperview];
  m_startupImage = nil;
}

- (void)setNavForItem:(FileNavigationItem*)p_item {
  if([p_item isDocument]) {
    // Set nav bars for a document
    [self hideNavbars];
  } else {
    // Set nav bars for a file browser
    [bottomNavBar hide];
  }
}

/**
 * Hide the navigation bars.
 */
- (void)hideNavbars {
	[navBar hide];
	[bottomNavBar hide];
	/*
	 //bcc, it used to be:
	GSLog(@"%s .", _cmd);
	struct CGRect rect = [defaults fullScreenApplicationContentRect];
	[textView setFrame:rect];
	[navBar hide:NO];
	[bottomNavBar hide:NO];
	[self hideSlider];
	//are we sure of this change
	*/
}

/**
 * Show the navigation bars.
 */
- (void)showNavbars {
	[navBar show];
	[bottomNavBar show];
}

/**
 * Toggle visibility of the navigation bars.
 */
- (void)toggleNavbars {
	GSLog(@"%s .", _cmd);
	[navBar toggle];
	[bottomNavBar toggle];
}

/**
 * Return YES if the image at the given path is an image.
 */
- (BOOL)isDocumentImage:(NSString*)p_path {
  NSString *ext = [p_path pathExtension];
  return ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"png"] || [ext isEqualToString:@"gif"]);
}

/**
 * Show the document and return the view used to allow for transition.
 */
- (UIView*)showDocumentAtPath:(NSString*)p_path {
  BOOL isPicture = [self isDocumentImage:p_path];
  UIView *ret = nil;
  
  [defaults setLastBrowserPath:p_path];
  if (isPicture) {
    ret = [[[EBookImageView alloc] initWithContentsOfFile:p_path withFrame:[mainView bounds] scaleAspect:YES] autorelease];
  } else { 
    //text or HTML file
    readingText = YES;
    UIView *progView;
    int subchapter = [defaults lastSubchapterForFile:p_path];
    EBookView *ebv = [[[EBookView alloc] initWithFrame:[mainView bounds] delegate:self parentView:mainView] autorelease];
    [ebv setDelegate:self];
    [ebv setBookPath:p_path subchapter:subchapter];
    
    // FIXME: It might make sense to move this kludge into the toolbar -- if m_offViewKludge is set,
    // return that for topView instead of a document or filebrowser.  Not sure if that would
    // break anything that calls topView, though.
    if(m_startupImage != nil) {
      progView = m_startupImage;
    } else {
      progView = [navBar topView];
    }
    
    [ebv loadSetDocumentWithProgressOnView:progView];
    
    ret = ebv;
  }  
  
  if (isPicture) {
    [navBar show];
    [bottomNavBar hide];
  } else {
    [navBar hide];
    if (![defaults toolbar]) {
      [bottomNavBar show];
    } else {
      [bottomNavBar hide];
    }
  }
  
  // Make sure the "file read" dot is updated.
  [[NSNotificationCenter defaultCenter] postNotificationName:OPENEDTHISFILE object:p_path];

  return ret;
}
/**
 * Called by the file browser objects when a user taps a file or folder.  Calls to navBar
 * to push whatever was tapped.  Navbar will call us back to actually open something.
 */
- (void)fileBrowser:(FileBrowser *)browser fileSelected:(NSString *)file {
	BOOL isDir = NO;
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  if(![fileManager fileExistsAtPath:file isDirectory:&isDir]) {
    GSLog(@"Tried to open non-existant path at %@", file);
    return;
  }
  
 	[defaults setLastBrowserPath:file];
  
  FileNavigationItem *tempItem;
	if (isDir) {
    FileBrowser *browser = [[FileBrowser alloc] initWithFrame:[mainView bounds]];
    [browser setPath:file];
    [browser setDelegate:self];
    [browser setExtensions:m_documentExtensions];
		tempItem = [[FileNavigationItem alloc] initWithPath:file browser:browser];
    [browser release];
	} else {
    // not a directory
    UIView *displayView = [self showDocumentAtPath:file];
		tempItem = [[FileNavigationItem alloc] initWithDocument:file view:displayView];
  }
  
  [navBar pushNavigationItem:tempItem];
  [tempItem release];
}

- (void)cleanUpBeforeQuit {
  FileNavigationItem *topItem = [navBar topItem];
	NSString *filename = [topItem path];
  GSLog(@"Saving last browser path at shutdown: %@", filename);
  [defaults setLastBrowserPath:filename];
  
  // Need to kick the top-most EBookView.  It doesn't clean up on its own at shutdown.
  UIView *top = [navBar topView];
  if([top respondsToSelector:@selector(saveBookPosition)]) {
    EBookView *eb = (EBookView*)top;
    [eb saveBookPosition];
  }
  
  
	[defaults setAppStatus:APPCLOSEDVALUE];
  GSLog(@"Books is terminating.");
  GSLog(@"========================================================");
}

- (void) applicationWillSuspend {
	[self cleanUpBeforeQuit];
}

- (void)embiggenText:(UINavBarButton *)button {
	if (![button isPressed]) {// mouse up events only, kids!
		[(EBookView*)[navBar topView] embiggenText];
		[defaults setTextSize:[(EBookView*)[navBar topView] textSize]];
	}
}

- (void)ensmallenText:(UINavBarButton *)button {
	if (![button isPressed]) {// mouse up events only, kids!
		[(EBookView*)[navBar topView] ensmallenText];
		[defaults setTextSize:[(EBookView*)[navBar topView] textSize]];
	}
}

- (void)invertText:(UINavBarButton *)button {
  if (![button isPressed]) { // mouse up events only, kids!
		textInverted = !textInverted;
		[(EBookView*)[navBar topView] invertText:textInverted];
		[defaults setInverted:textInverted];
		[self adjustStatusBarColorWithUiOrientation:-1];
//		struct CGRect rect = [defaults fullScreenApplicationContentRect];
//		[(EBookView*)[navBar topView] setFrame:rect];
	}	
}

- (void)pageDown:(UINavBarButton *)button {
	if (![button isPressed]) {
		[(EBookView*)[navBar topView] pageDownWithTopBar:![defaults navbar]
						   bottomBar:![defaults toolbar]];
	}	
}

- (void)pageUp:(UINavBarButton *)button {
	if (![button isPressed]) {
		[(EBookView*)[navBar topView] pageUpWithTopBar:![defaults navbar]
						 bottomBar:![defaults toolbar]];
	}	
}

/**
 * Advance to the next chapter, either using chapterdHtml or moving to the
 * next file in the file browser.
 */
- (void)chapForward:(UINavBarButton *)button {
	if (![button isPressed]) {
		if ([(EBookView*)[navBar topView] gotoNextSubchapter] == YES) {
			[navBar hide];
			[bottomNavBar hide];
		} else {
			NSString *nextFile = [[navBar topBrowser] fileAfterFileNamed:[defaults lastBrowserPath]];
			if(nextFile != nil) {
        UIView *newView = [self showDocumentAtPath:nextFile];
				FileNavigationItem *tempItem = [[FileNavigationItem alloc] initWithDocument:nextFile view:newView];
				[navBar replaceTopNavigationItem:tempItem];
				[tempItem release];
			}
		}
	}	
}

/**
 * Retreat to the last chapter, either using chapteredHtml or moving
 * to the next file in the file browser.
 */
- (void)chapBack:(UINavBarButton *)button {
	if (![button isPressed]) {
		if ([(EBookView*)[navBar topView] gotoPreviousSubchapter] == YES) {
			[navBar hide];
			[bottomNavBar hide];
		} else {
      FileBrowser *fb = [navBar topBrowser];
			NSString *prevFile = [fb fileBeforeFileNamed:[defaults lastBrowserPath]];
			if(nil != prevFile) {
        UIView *newView = [self showDocumentAtPath:prevFile];
				FileNavigationItem *tempItem = [[FileNavigationItem alloc] initWithDocument:prevFile view:newView];
				[navBar replaceTopNavigationItem:tempItem];
        [tempItem release];
			}
		}
	}	
}

/**
 * Create or reconfigure the nav bar (file browser).
 */
- (void)setupNavbar {
	struct CGRect rect = [mainView bounds];
  struct CGRect frameRect = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, TOOLBAR_HEIGHT);
  
  // Remove any old navBar
  if(navBar == nil) {    
    navBar = [[HideableNavBar alloc] initWithFrame:frameRect delegate:self transitionView:m_transitionView];
    [navBar hideButtons];
    
    float lMargin = 45.0f;
    [navBar setRightMargin:lMargin];
    //position the prefsButton in the margin
    //for some reason cannot click on the button when it is there
    prefsButton = [self toolbarButtonWithName:@"prefs" rect:CGRectMake(rect.size.width-lMargin,9,40,30) selector:@selector(showPrefs:) flipped:NO];
    //prefsButton = [self toolbarButtonWithName:@"prefs" rect:CGRectMake(275,9,40,30) selector:@selector(showPrefs:) flipped:NO];
    
    [navBar addSubview:prefsButton];
    
  } else {
    /*
    [navBar retain];
    [navBar removeFromSuperview];
    [navBar setFrame:frameRect];
    float lMargin = 45.0f;
    [prefsButton setFrame:CGRectMake(frameRect.size.width-lMargin,9,40,30) ];
    [mainView addSubview:navBar];
    [navBar release];
     */
  }	
}

/**
 * Create or reconfigure the tool bar (reader).
 */
- (void)setupToolbar {
	struct CGRect rect = [mainView bounds];
  struct CGRect frameRect = CGRectMake(rect.origin.x, rect.size.height - TOOLBAR_HEIGHT, rect.size.width, TOOLBAR_HEIGHT);
  
  if(bottomNavBar == nil) {
    // FIXME: This will never redraw the nav bars after prefs.
    bottomNavBar = [[HideableNavBar alloc] initWithFrame:frameRect delegate:self transitionView:m_transitionView];
    [bottomNavBar setBarStyle:0];
    
    // Put the buttons back
    if ([defaults flipped]) {
      downButton = [self toolbarButtonWithName:@"down" rect:CGRectMake(5,9,40,30) selector:@selector(pageDown:) flipped:YES];
      upButton = [self toolbarButtonWithName:@"up" rect:CGRectMake(45,9,40,30) selector:@selector(pageUp:) flipped:YES];

      if (![defaults pagenav]) { // If pagnav buttons should be off, then move the chapter buttons over
        leftButton = [self toolbarButtonWithName:@"left" rect:CGRectMake(5,9,40,30) selector:@selector(chapBack:) flipped:NO];
        rightButton = [self toolbarButtonWithName:@"right" rect:CGRectMake(45,9,40,30) selector:@selector(chapForward:) flipped:NO];
      } else {
        leftButton = [self toolbarButtonWithName:@"left" rect:CGRectMake(88,9,40,30) selector:@selector(chapBack:) flipped:NO];
        rightButton = [self toolbarButtonWithName:@"right" rect:CGRectMake(128,9,40,30) selector:@selector(chapForward:) flipped:NO];	
      }

      rotateButton = [self toolbarButtonWithName:@"rotate" rect:CGRectMake(171,9,30,30) selector:@selector(rotateButtonCallback:) flipped:NO];
      invertButton = [self toolbarButtonWithName:@"inv" rect:CGRectMake(203,9,30,30) selector:@selector(invertText:) flipped:NO];
      minusButton = [self toolbarButtonWithName:@"emsmall" rect:CGRectMake(235,9,40,30) selector:@selector(ensmallenText:) flipped:NO];
      plusButton = [self toolbarButtonWithName:@"embig" rect:CGRectMake(275,9,40,30) selector:@selector(embiggenText:) flipped:NO];
    } else {
      minusButton = [self toolbarButtonWithName:@"emsmall" rect:CGRectMake(5,9,40,30) selector:@selector(ensmallenText:) flipped:NO];
      plusButton = [self toolbarButtonWithName:@"embig" rect:CGRectMake(45,9,40,30) selector:@selector(embiggenText:) flipped:NO];
      invertButton = [self toolbarButtonWithName:@"inv" rect:CGRectMake(87,9,30,30) selector:@selector(invertText:) flipped:NO];
      rotateButton = [self toolbarButtonWithName:@"rotate" rect:CGRectMake(119,9,30,30) selector:@selector(rotateButtonCallback:) flipped:NO];

      if (![defaults pagenav]) { // If pagnav buttons should be off, then move the chapter buttons over
        leftButton = [self toolbarButtonWithName:@"left" rect:CGRectMake(235,9,40,30) selector:@selector(chapBack:) flipped:NO];
        rightButton = [self toolbarButtonWithName:@"right" rect:CGRectMake(275,9,40,30) selector:@selector(chapForward:) flipped:NO];
      } else {
        leftButton = [self toolbarButtonWithName:@"left" rect:CGRectMake(152,9,40,30) selector:@selector(chapBack:) flipped:NO];
        rightButton = [self toolbarButtonWithName:@"right" rect:CGRectMake(192,9,40,30) selector:@selector(chapForward:) flipped:NO];
      }

      upButton = [self toolbarButtonWithName:@"up" rect:CGRectMake(235,9,40,30) selector:@selector(pageUp:) flipped:NO];
      downButton = [self toolbarButtonWithName:@"down" rect:CGRectMake(275,9,40,30) selector:@selector(pageDown:) flipped:NO];
    }

    [bottomNavBar addSubview:minusButton];
    [bottomNavBar addSubview:plusButton];
    [bottomNavBar addSubview:invertButton];
    [bottomNavBar addSubview:rotateButton];

    if ([defaults chapternav]) {
      [bottomNavBar addSubview:leftButton];
      [bottomNavBar addSubview:rightButton];
    }
    
    if ([defaults pagenav]) {	
      [bottomNavBar addSubview:upButton];
      [bottomNavBar addSubview:downButton];
    }
  }
}

/**
 * Return a pre-configured toolbar button with _up and _down images setup.
 */
- (UINavBarButton *)toolbarButtonWithName:(NSString *)name rect:(struct CGRect)rect selector:(SEL)selector flipped:(BOOL)flipped {
	UINavBarButton	*button = [[UINavBarButton alloc] initWithFrame:rect];

	[button setAutosizesToFit:NO];
	[button setImage:[self navBarImage:[NSString stringWithFormat:@"%@_up",name] flipped:flipped] forState:0];
	[button setImage:[self navBarImage:[NSString stringWithFormat:@"%@_down",name] flipped:flipped] forState:1];
	[button setDrawContentsCentered:YES];
	[button addTarget:self action:selector forEvents: (255)];
	[button setNavBarButtonStyle:0];
	//bcc this complains about an invalid context, it seems to work fine without anyway
	//	[button drawImageAtPoint:CGPointMake(5.0f,0.0f) fraction:0.5];
	[button setEnabled:YES];
	return button;
}

/**
 * Get an image from the bundle.
 */
- (UIImage *)navBarImage:(NSString *)name flipped:(BOOL)flipped {
	NSBundle *bundle = [NSBundle mainBundle];
	imgPath = [bundle pathForResource:name ofType:@"png"];
	UIImage *buttonImg = [[UIImage alloc]initWithContentsOfFile:imgPath];
	if (flipped) [buttonImg setOrientation:4];
	return [buttonImg autorelease];
}

/**
 * Redraw the toolbar when the user's choice of visible buttons changes.
 */
- (void)updateToolbar:(NSNotification *)notification {
	BOOL lBottomBarHidden = [bottomNavBar hidden];
  [bottomNavBar retain];
	[bottomNavBar removeFromSuperview];
	[self setupToolbar];
	[mainView addSubview:bottomNavBar];
  [bottomNavBar release];
	if (lBottomBarHidden) {
    [bottomNavBar hide];
  }
}

- (void)setTextInverted:(BOOL)b {
	textInverted = b;
}

- (void)showPrefs:(UINavBarButton *)button {
	if (![button isPressed]) // mouseUp only
	{
		GSLog(@"Showing Preferences View");
		PreferencesController *prefsController = [[PreferencesController alloc] initWithAppController:self];
		[prefsButton setEnabled:false];
		[prefsController showPreferences];
	}
}

- (UIWindow *)appsMainWindow {
	return window;
}

- (void)anotherApplicationFinishedLaunching:(struct __GSEvent *)event {
	[self applicationWillSuspend];
}

- (NSString *)currentBrowserPath {
	return [[navBar topBrowser] path];
}

/**
 * Adjust toolbar to match current inversion status.
 *
 * @param p_orientation UI Orientation - pass -1 to use the current hardware orientation.
 */
- (void)adjustStatusBarColorWithUiOrientation:(int)p_orientation {
  int ori = p_orientation;
  if(p_orientation == -1) {
    ori = [defaults uiOrientation];
  }
  
  int angle = [self angleForOrientation:ori];

	if ([defaults inverted]) {
		[self setStatusBarMode:3 orientation:angle duration:0.25];
	} else {
		[self setStatusBarMode:0 orientation:angle duration:0.25];
	}
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
	[navBar release];
	[bottomNavBar release];
	[mainView release];
	[defaults release];
	[minusButton release];
	[plusButton release];
	[invertButton release];
	[rotateButton release];
  [m_documentExtensions release];
	[super dealloc];
}

/**
 * Callback for the rotation toolbar button to call.
 */
- (void) rotateButtonCallback:(UINavBarButton*) button {
	if (![button isPressed]) {
		[defaults setRotateLocked:![defaults isRotateLocked]];
	}	
}


/**
 * Toggle rotation status.
 */
- (void)rotateApp {
  // Note most of the rotate code is in UIOrientingApplication.
  // The rest is in the various objects which respond to rotation notifications.
  /*
  BOOL bWasRotated = [defaults isRotate90];  
  float rotateDegrees;
  float statusBarDegrees;
  
  if(bWasRotated) {
    statusBarDegrees = 0.0;
    rotateDegrees = -90.0f;
  } else {
    statusBarDegrees = 90.0f;
    rotateDegrees = 90.0f;
  }
  
  [defaults setRotate90:![defaults isRotate90]];
  
  GSLog(@"Starting rotate");
//  [navBar performSelectorOnItemViews:@selector(setRotationBy:) withObject:[NSNumber numberWithFloat:degrees]];
  [mainView setRotationBy:rotateDegrees];
  [mainView setFrame:[defaults fullScreenApplicationContentRect]];

  [self setStatusBarMode:0 orientation:statusBarDegrees duration:0 fenceID:nil animation:0];
  
	*/
  
  /*
	CGSize lContentSize = [textView contentSize];	
	//GSLog(@"contentSize:w=%f, h=%f", lContentSize.width, lContentSize.height);
	//GSLog(@"rotateApp");
	CGRect rect = [window frame];
	CGAffineTransform lTransform = CGAffineTransformMakeTranslation(0,0);
	[self adjustStatusBarColorWithUiOrientation:-1];
  
	if ([defaults isRotate90]) {
		int degree = 90;
		CGAffineTransform lTransform2  = CGAffineTransformMake(0, 1, -1, 0, 0, 0);
		//BCC: translate to have the center of rotation (top left corner) in the middle of the view
		lTransform = CGAffineTransformTranslate(lTransform, -1*rect.size.width/2, -1*rect.size.height/2);
		//BCC: perform the actual rotation
		lTransform = CGAffineTransformConcat(lTransform2, lTransform);
		//BCC: translate back so the bottom right corner of the view is at the bottom left of the phone
		//BCC: translate back so the top left corner of the view is at the top right of the phone
		lTransform = CGAffineTransformTranslate(lTransform, rect.size.width/2, -rect.size.height/2);
	} 

	struct CGAffineTransform lMatrixprev = [window transform];

	if(!CGAffineTransformEqualToTransform(lTransform,lMatrixprev)) {
		//remember the previous position
		struct CGRect overallRect = [[textView _webView] frame];
		//GSLog(@"overall height: %f", overallRect.size.height);
		struct CGRect visRect = [textView visibleRect];
		float scrollPercentage = visRect.origin.y / overallRect.size.height;
		if ([defaults isRotate90]) {
			[window setFrame: rect];
			//[window setBounds: rect];
      
			[mainView setFrame: rect];
			//[mainView setBounds: rect];
		}

		[m_transitionView setFrame: rect];
    
    
		[textView setFrame: rect];
		[self refreshTextViewFromDefaultsToolbarsOnly];
		[textView setDelegate:self];
		int            subchapter = [textView getSubchapter];
		NSString      *recentFile   = [textView currentPath];


		overallRect = [[textView _webView] frame];
		//		GSLog(@"new overall height: %f", overallRect.size.height);
		float scrollPoint = (float) scrollPercentage * overallRect.size.height;

    // FIXME: There's probably a better way to do this than reloading the whole book
//		[textView loadBookWithPath:recentFile subchapter:subchapter];
		[textView scrollPointVisibleAtTopLeft:CGPointMake (0.0f, scrollPoint) animated:NO];
    
        
		[window setTransform: lTransform];

		if (![defaults isRotate90]) {
			rect.origin.y+=20; //to take into account the status bar
			[window setFrame: rect];
		}
		[UIView endAnimations];
		[self updateToolbar: 0];
		[self updateNavbar];

		//[navBar showTopNavBar:NO];
		//[navBar show];
		[bottomNavBar hide];
	}
*/

	//BCC: animate this
	/*	
		UITransformAnimation *scaleAnim = [[UITransformAnimation alloc] initWithTarget: window];
		struct CGAffineTransform lMatrixprev = [window transform];
		[scaleAnim setStartTransform: lMatrixprev];
		[scaleAnim setEndTransform: lTransform];
		[anim addAnimation:scaleAnim withDuration:5.0f start:YES]; 
		[anim autorelease];	//should we do this, it continues to leave for the duration of the animation
		*/
}

/**
 * Ensure that the preferences screen can't be shown multiple times while the animation is in progress.
 */
- (void) preferenceAnimationDidFinish {
	[prefsButton setEnabled:true];
}

/**
 * Creates a CGImage containing something appropriate to show the next time Books launches.
 *
 * If we're reading a book with a cover image, it's scaled and used.  If we're reading a book
 * without a cover image, we take a screen shot of the book's text.
 * If we're on the file browser, we take a screen shot of it.
 */
- (struct CGImage *)createApplicationDefaultPNG {
  struct CGImage *ret;
  NSString *sCover = [EBookImageView coverArtForBookPath:[defaults lastBrowserPath]];
  
  const float SHOT_WIDTH  = 320;
  const float SHOT_HEIGHT = 460;
  const int BYTES_PER_PIXEL = 4;
  
  if([sCover length] > 0) {
    UIImage *img = [UIImage imageAtPath:sCover];
    struct CGImage *imageRef = [img imageRef];
    
    // We need to resize this to exactly what the phone wants.
    // Image resize code taken from code believed to be GPL attributed
    // to Sean Heber.  (Thanks Sean!!!)
    
    // Create a new image of the right size (startup code is picky about the Default image size)
    CGContextRef bitmap = CGBitmapContextCreate(
      NULL, SHOT_WIDTH, SHOT_HEIGHT, CGImageGetBitsPerComponent(imageRef),
      BYTES_PER_PIXEL*SHOT_WIDTH, CGImageGetColorSpace(imageRef), CGImageGetBitmapInfo(imageRef)
    );
    
    // Scale it and set for return.
    CGContextDrawImage( bitmap, CGRectMake(0, 0, SHOT_WIDTH, SHOT_HEIGHT), imageRef );
    ret = CGBitmapContextCreateImage( bitmap );
    CGContextRelease(bitmap);
  } else {
    // Take a screen shot of the top view.
    ret = [mainView createSnapshotWithRect:CGRectMake(0, 0, SHOT_WIDTH, SHOT_HEIGHT)];
    CGImageRetain(ret);
  }
  
  return ret;
}

/**
 * Called by UIKit when it's time to write out our default image - usually at shutdown.
 */
- (void)_updateDefaultImage {
  // Check for cover art or get a screen shot:
  struct CGImage *imgRef = [self createApplicationDefaultPNG];
  
  // Find the path to write it to:
  NSString *pathToDefault = [self _pathToDefaultImageNamed:[self nameOfDefaultImageToUpdateAtSuspension]];  
  
  // Need to create the directory tree.
  NSString *destDirectory = [pathToDefault stringByDeletingLastPathComponent];
  NSArray *pathComponents = [destDirectory pathComponents];
  NSString *pathPart = @"/";

  int i;
  int n = [pathComponents count];
  for(i=0; i < n; i++) {
    pathPart = [pathPart stringByAppendingPathComponent:[pathComponents objectAtIndex:i]];
    [[NSFileManager defaultManager] createDirectoryAtPath:pathPart attributes:nil];
  } 
  
  // Dump a CGImage to file
  NSURL *urlToDefault = [NSURL fileURLWithPath:pathToDefault];
  CGImageDestinationRef dest = CGImageDestinationCreateWithURL((CFURLRef)urlToDefault, CFSTR("public.jpeg")/*kUTTypeJPEG*/, 1, NULL);
  CGImageDestinationAddImage(dest, imgRef, NULL);
  CGImageDestinationFinalize(dest);
  CGImageRelease(imgRef);
}

/**
 * Gets a suffix for the image name to write for startup.
 */
- (id)nameOfDefaultImageToUpdateAtSuspension {
    return @"Default";
}
@end