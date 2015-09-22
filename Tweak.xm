@interface SBHomeScreenPreviewView : UIView
+ (id)preview;
@end

@interface SBLockScreenManager : NSObject
@property (nonatomic,readonly) UIViewController *lockScreenViewController;
+ (id)sharedInstance;
- (BOOL)isUILocked;
@end

@interface SBUIAnimationFadeAlertToSpringBoard : NSObject
- (void)endAnimation;
@end

@interface SBSearchResultsBackdropView : UIView
- (void)setTransitionProgress:(CGFloat)arg1;
- (void)prepareForTransition;
@end

@interface SBRootFolderView : UIView
- (UIScrollView *)scrollView;
@end

@interface	SBRootFolderController
@property (nonatomic,retain,readonly) SBRootFolderView *contentView;
@end

@interface SBIconController : NSObject
+ (SBIconController *)sharedInstance;
- (SBRootFolderController *)rootFolder;
@end

@interface SBLockScreenView : UIView
//new
@property (nonatomic, retain) SBSearchResultsBackdropView *blurringView;
@property (nonatomic, retain) UIView *darkeningView;
@end

#define kFadeDuration 0.4

static BOOL needsOverrideIconScatterAnimation = NO;

%hook SBLockScreenView

%property (nonatomic, retain) SBSearchResultsBackdropView *blurringView;
%property (nonatomic, retain) UIView *darkeningView;

- (id)initWithFrame:(CGRect)arg1 {
	SBLockScreenView *o = %orig;

	// create homescreen snapshot
	SBHomeScreenPreviewView *snapshotView = [%c(SBHomeScreenPreviewView) preview];
	snapshotView.userInteractionEnabled = NO;
	snapshotView.subviews[0].hidden = YES; // hide snapshot wallpaper

	// set snapshot page to match homescreen page
	SBRootFolderView *rootFolderView = (SBRootFolderView *)snapshotView.subviews[1];
	rootFolderView.scrollView.contentOffset = MSHookIvar<SBRootFolderController *>(((SBIconController *)[%c(SBIconController) sharedInstance]),"_rootFolderController").contentView.scrollView.contentOffset;

	// create blurring view
	self.blurringView = [[%c(SBSearchResultsBackdropView) alloc] initWithFrame:snapshotView.frame];
	[self.blurringView prepareForTransition];
	[self.blurringView setTransitionProgress:1];

	// create darkening view
	self.darkeningView = [[UIView alloc] initWithFrame:snapshotView.frame];
	self.darkeningView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];

	// add to view
	[self insertSubview:snapshotView belowSubview:MSHookIvar<UIView*>(o,"_wallpaperBlurView")];
	[self insertSubview:self.blurringView belowSubview:MSHookIvar<UIView*>(o,"_wallpaperBlurView")];
	[self insertSubview:self.darkeningView belowSubview:MSHookIvar<UIView*>(o,"_wallpaperBlurView")];

	// hide default overlays
	MSHookIvar<UIView*>(self,"_wallpaperBlurView").hidden = YES;

	return o;
}

- (void)_updateOverlaysForScroll:(CGFloat)arg1 passcodeView:(id)arg2 {
	// remove dark passcode overlay
	%orig(0,arg2);
}

- (void)dealloc {
	[self.blurringView release];
	[self.darkeningView release];
	%orig;
}

%end

%hook SBUIAnimationZoomDownLockScreenToHome

- (void)animateZoomWithCompletion:(void (^)(BOOL))comp {
	// override fingerprint unlock animation
	[UIView animateWithDuration:kFadeDuration delay:0 options: UIViewAnimationCurveEaseOut animations:^{
		SBLockScreenView *lsView = (SBLockScreenView *)((SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance]).lockScreenViewController.view;
		lsView.darkeningView.alpha = 0;
		[lsView.blurringView setTransitionProgress:0];
		MSHookIvar<UIView*>(lsView,"_foregroundView").alpha = 0;
	} completion:comp];
}

%end

%hook SBUIAnimationFadeAlertToSpringBoard

- (void)beginAnimation {
	// override passcode unlock animation
	if([MSHookIvar<id>(self,"_fromAlert") isKindOfClass:%c(SBLockScreenViewController)]) {
		[UIView animateWithDuration:kFadeDuration delay:0 options: UIViewAnimationCurveEaseOut animations:^{
			SBLockScreenView *lsView = (SBLockScreenView *)((SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance]).lockScreenViewController.view;
			lsView.darkeningView.alpha = 0;
			[lsView.blurringView setTransitionProgress:0];
			MSHookIvar<UIView*>(lsView,"_foregroundView").alpha = 0;
		 }
		 completion:^(BOOL c){
			%orig;
			needsOverrideIconScatterAnimation = YES;
			[self endAnimation];
		}];
	 }
	 else {
	 	%orig;
	}
}

%end

%hook SBWallpaperController

- (id)_wallpaperViewForVariant:(long long)arg1 {
	// replace lockscreen wallpaper with homescreen one
	if(arg1 == 0) {
		return %orig(1);
	}
	else {
		return %orig;
	}
}

%end

%hook SBUIController

- (void)restoreContentAndUnscatterIconsAnimated:(BOOL)arg1 withCompletion:(/*^block*/id)arg2 {
	// stop icon scatter for passcode animation
	%orig(needsOverrideIconScatterAnimation?NO:arg1,arg2);
	needsOverrideIconScatterAnimation = NO;
}

%end

%hook SBLockScreenViewController

- (long long)statusBarStyle {
	// override status bar style to smooth transition
	return UIStatusBarStyleLightContent;
}

%end
