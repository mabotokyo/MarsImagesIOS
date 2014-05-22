//
//  MarsImageViewController.m
//  Mars-Images
//
//  Created by Mark Powell on 10/26/13.
//  Copyright (c) 2013 Powellware. All rights reserved.
//

#import "MarsImageViewController.h"
#import "Evernote.h"
#import "IIViewDeckController.h"
#import "MarsImageCaptionView.h"
#import "MarsImageNotebook.h"
#import "MarsPhoto.h"
#import "MarsSidePanelController.h"
#import "PSMenuItem.h"
#import <QuartzCore/QuartzCore.h>

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@interface MarsImageViewController ()

@end

@implementation MarsImageViewController

typedef enum {
    CLOCK_BUTTON,
    ABOUT_BUTTON,
    MOSAIC_BUTTON,
    MAP_BUTTON
} Buttons;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.delegate = self;
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _imageSelectionButton = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStyleBordered target:self action:@selector(imageSelectionButtonPressed:)];
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7")) {
        _imageSelectionButton.tintColor = [MarsImageViewController defaultSystemTintColor];
    }
    
    _shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareImage:)];
    [PSMenuItem installMenuHandlerForObject:self];
    self.wantsFullScreenLayout = NO; //otherwise we get an unsightly gap between the nav and status bar
    
    _segmentedControl = [[UISegmentedControl alloc] init];
    [_segmentedControl insertSegmentWithImage:[UIImage imageNamed:@"clock"] atIndex:CLOCK_BUTTON animated:NO];
    [_segmentedControl insertSegmentWithImage:[[UIButton buttonWithType:UIButtonTypeInfoLight] currentImage] atIndex:ABOUT_BUTTON animated:NO];
    [_segmentedControl insertSegmentWithImage:[[UIButton buttonWithType:UIButtonTypeContactAdd] currentImage] atIndex:MOSAIC_BUTTON animated:NO];
    [_segmentedControl insertSegmentWithImage:[UIImage imageNamed:@"103-map"] atIndex:MAP_BUTTON animated:NO];
    _segmentedControl.momentary = YES;
    [_segmentedControl setSegmentedControlStyle:UISegmentedControlStyleBar];
    [_segmentedControl sizeToFit];
    [_segmentedControl addTarget:self action:@selector(segmentedControlButtonPressed:) forControlEvents:UIControlEventValueChanged];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notesLoaded:) name:END_NOTE_LOADING object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageSelected:) name:IMAGE_SELECTED object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self configureToolbarAndNavbar];
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self configureToolbarAndNavbar];
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

+ (UIColor*)defaultSystemTintColor { // IOS 7 only
    static UIColor* systemTintColor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIWindow* window = [[UIWindow alloc] init];
        systemTintColor = window.tintColor;
    });
    return systemTintColor;
}

- (IBAction) toggleTableView: (id)sender {
    [self.viewDeckController toggleLeftViewAnimated:YES];
}

- (void) segmentedControlButtonPressed: (id)sender {
    UIViewController* vc;
    UIStoryboard* storyboard = self.navigationController.storyboard;
    self.navigationItem.title = nil;
    switch (_segmentedControl.selectedSegmentIndex) {
        case ABOUT_BUTTON:
            vc = [storyboard instantiateViewControllerWithIdentifier:@"about"];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        case CLOCK_BUTTON:
            vc = [storyboard instantiateViewControllerWithIdentifier:@"time"];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        case MOSAIC_BUTTON:
            vc = [storyboard instantiateViewControllerWithIdentifier:@"mosaic"];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        case MAP_BUTTON:
            vc = [storyboard instantiateViewControllerWithIdentifier:@"map"];
            [self.navigationController pushViewController:vc animated:YES];
            break;
    }
}

- (void) notesLoaded: (NSNotification*) notification {
    int numNotesReturned = 0;
    NSNumber* num = [notification.userInfo objectForKey:NUM_NOTES_RETURNED];
    if (num) {
        numNotesReturned = [num intValue];
    }
    if (numNotesReturned > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadData];
        });
    }
}

- (MarsPhoto*) currentPhoto {
    NSArray* photos = [MarsImageNotebook instance].notePhotosArray;
    if (photos.count == 0)
        return nil;
    return (MarsPhoto*)[photos objectAtIndex:self.currentIndex];
}

- (void) imageSelected: (NSNotification*) notification {
    NSNumber* num = [notification.userInfo valueForKey:IMAGE_INDEX];
    int index = [num intValue];
    UIViewController* sender = [notification.userInfo valueForKey:SENDER];
    if (sender != self && index != [self currentIndex]) {
        [self setCurrentPhotoIndex: index];
        [self configureToolbarAndNavbar];
    }
}

- (void) imageSelectionButtonPressed: (id)sender {
    [self becomeFirstResponder];
    NSArray* resources = [self currentPhoto].note.resources;
    if (!resources || resources.count <=1) {
        return;
    }
    
    int resourceIndex = 0;
    NSMutableArray* menuItems = [[NSMutableArray alloc] init];
    for (EDAMResource* resource in resources) {
        NSString* imageName = [[MarsImageNotebook instance].mission imageName:resource];
        PSMenuItem *menuItem = [[PSMenuItem alloc] initWithTitle:imageName
                                                           block:^{
                                                               [[MarsImageNotebook instance] changeToImage:resourceIndex forNote:self.currentIndex];
                                                               [self reloadData];
                                                           }];
        [menuItems addObject:menuItem];
        resourceIndex += 1;
    }
    
    NSArray* leftAndRight = [[MarsImageNotebook instance].mission stereoForImages:resources];
    if (leftAndRight.count > 0) {
        PSMenuItem* menuItem = [[PSMenuItem alloc] initWithTitle:@"Anaglyph"
                                                             block:^{
                                                                 [[MarsImageNotebook instance] changeToAnaglyph: leftAndRight noteIndex:self.currentIndex];
                                                                 [self reloadData];
                                                             }];
        [menuItems addObject:menuItem];
    }
    
    if ([menuItems count] > 1) {
        [UIMenuController sharedMenuController].menuItems = menuItems;
        CGRect bounds = self.navigationController.toolbar.frame;
        bounds.origin.y -= bounds.size.height;
        [[UIMenuController sharedMenuController] setTargetRect:bounds inView:self.view];
        [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
    }
}

- (void) configureToolbarAndNavbar {

    int resourceCount = 0;
    MarsPhoto* photo = [self currentPhoto];
    resourceCount = photo.note.resources.count;
    for (UIView* view in [self.view subviews]) {
        if ([view isKindOfClass:[UIToolbar class]]) {
            UIBarButtonItem *flexibleItem1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            UIBarButtonItem *flexibleItem2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            UIToolbar* toolbar = (UIToolbar*)view;
            toolbar.hidden = NO;
            if (resourceCount > 1 && toolbar.frame.size.width > 100) {
                NSString* imageName = @"";
                if (photo.leftAndRight)
                    imageName = @"Anaglyph";
                else
                    imageName = [[MarsImageNotebook instance].mission imageName:photo.resource];
                
                [_imageSelectionButton setTitle:imageName];

                [toolbar setItems:[NSArray arrayWithObjects:flexibleItem1, _imageSelectionButton, flexibleItem2, nil]];
            }
            else
                [toolbar setItems:[NSArray arrayWithObjects:nil]];
        }
    }

    if (self.view.frame.size.width <= 100) {
        self.alwaysShowControls = YES;
        self.navigationItem.titleView = [[UILabel alloc] init];
        self.navigationItem.rightBarButtonItem = nil;
    } else {
        self.alwaysShowControls = NO;
        self.navigationItem.rightBarButtonItem = _shareButton;
        self.navigationItem.titleView = _segmentedControl;
    }
}

- (IBAction) shareImage:(id)sender {
    MarsPhoto* marsImage = [self currentPhoto];
    if (!marsImage) return;
    EDAMNote* note = marsImage.note;
    UIImage* image = marsImage.underlyingImage;
    
    NSString* missionName = [MarsImageNotebook instance].missionName;
    NSArray* activities = [NSArray arrayWithObjects: [NSString stringWithFormat: @"%@ image sent from Mars images", missionName], image, nil];
    UIActivityViewController* activityView = [[UIActivityViewController alloc] initWithActivityItems:activities applicationActivities:nil];
    [activityView setValue: [NSString stringWithFormat: @"%@ image %@", missionName, note.title] forKey: @"subject"];
    activityView.excludedActivityTypes = [NSArray arrayWithObjects: UIActivityTypeAssignToContact, nil];
    
    activityView.completionHandler = ^(NSString *activityType, BOOL completed) {
        NSLog(@"Activity Type selected: %@", activityType);
        if (completed) {
            NSLog(@"Selected activity was performed.");
        } else {
            if (activityType == NULL) {
                NSLog(@"User dismissed the view controller without making a selection.");
            } else {
                NSLog(@"Activity was not performed.");
            }
        }
    };
    
    [self presentViewController:activityView animated:YES completion:nil];
}

#pragma mark MWPhotoBrowserDelegate

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return [MarsImageNotebook instance].notePhotosArray.count;
}

- (id<MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    NSArray* photosArray = [MarsImageNotebook instance].notePhotosArray;
    if (photosArray.count > 0)
        return [photosArray objectAtIndex:index];
    return nil;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser didDisplayPhotoAtIndex:(NSUInteger)index {
    [self configureToolbarAndNavbar];
    
    int count = [MarsImageNotebook instance].notePhotosArray.count;
    if (index == count-1) {
        [[MarsImageNotebook instance] loadMoreNotes:count withTotal:NOTE_PAGE_SIZE];
    }
    [(MarsSidePanelController*)self.viewDeckController imageSelected:index from:self];
}

- (MWCaptionView *)photoBrowser:(MWPhotoBrowser *)photoBrowser captionViewForPhotoAtIndex:(NSUInteger)index {
    if ([MarsImageNotebook instance].notePhotosArray.count > index)
        return [[MarsImageCaptionView alloc] initWithPhoto:[[MarsImageNotebook instance].notePhotosArray objectAtIndex:index]];

    return nil;
}

@end
