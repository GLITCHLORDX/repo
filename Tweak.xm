#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static UIView *dcxRoot = nil;
static UILabel *dcxClockLabel = nil;
static UILabel *dcxDateLabel = nil;
static UIView *dcxOcclusionLayer = nil;
static NSTimer *dcxTimer = nil;
static BOOL dcxVisible = NO;

static BOOL DCXClassNameContains(UIView *view, NSString *needle) {
    if (!view || !needle) return NO;
    NSString *name = NSStringFromClass([view class]);
    return [name rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static void DCXHideStockClockViews(UIView *root) {
    if (!root) return;
    for (UIView *sub in root.subviews) {
        NSString *className = NSStringFromClass([sub class]);
        BOOL likelyClock =
            [className rangeOfString:@"DateView" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [className rangeOfString:@"TimeView" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [className rangeOfString:@"Clock" options:NSCaseInsensitiveSearch].location != NSNotFound;

        if (likelyClock && sub != dcxRoot && ![sub isDescendantOfView:dcxRoot]) {
            sub.alpha = 0.0;
            sub.hidden = YES;
        }
        DCXHideStockClockViews(sub);
    }
}

static NSString *DCXCurrentTimeText(void) {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [NSLocale currentLocale];
    fmt.dateFormat = @"h:mm";
    return [fmt stringFromDate:[NSDate date]];
}

static NSString *DCXCurrentDateText(void) {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [NSLocale currentLocale];
    fmt.dateFormat = @"EEEE, d MMMM";
    return [[fmt stringFromDate:[NSDate date]] uppercaseString];
}

static void DCXUpdateClock(void) {
    if (!dcxClockLabel || !dcxDateLabel) return;
    dcxClockLabel.text = DCXCurrentTimeText();
    dcxDateLabel.text = DCXCurrentDateText();
}

static UIWindow *DCXMainWindow(void) {
    UIWindow *key = [UIApplication sharedApplication].keyWindow;
    if (key) return key;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (!w.hidden && w.alpha > 0.01) return w;
    }
    return nil;
}

static void DCXBuildClockIfNeeded(void) {
    UIWindow *window = DCXMainWindow();
    if (!window || dcxRoot) return;

    CGRect b = window.bounds;
    dcxRoot = [[UIView alloc] initWithFrame:b];
    dcxRoot.userInteractionEnabled = NO;
    dcxRoot.backgroundColor = UIColor.clearColor;
    dcxRoot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dcxRoot.tag = 260126;

    dcxClockLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 78, b.size.width, 105)];
    dcxClockLabel.textAlignment = NSTextAlignmentCenter;
    dcxClockLabel.textColor = UIColor.whiteColor;
    dcxClockLabel.font = [UIFont systemFontOfSize:82 weight:UIFontWeightSemibold];
    dcxClockLabel.adjustsFontSizeToFitWidth = YES;
    dcxClockLabel.minimumScaleFactor = 0.65;
    dcxClockLabel.layer.shadowColor = UIColor.blackColor.CGColor;
    dcxClockLabel.layer.shadowOpacity = 0.45;
    dcxClockLabel.layer.shadowRadius = 8.0;
    dcxClockLabel.layer.shadowOffset = CGSizeMake(0, 3);

    dcxDateLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 55, b.size.width, 26)];
    dcxDateLabel.textAlignment = NSTextAlignmentCenter;
    dcxDateLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
    dcxDateLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    dcxDateLabel.layer.shadowColor = UIColor.blackColor.CGColor;
    dcxDateLabel.layer.shadowOpacity = 0.35;
    dcxDateLabel.layer.shadowRadius = 5.0;
    dcxDateLabel.layer.shadowOffset = CGSizeMake(0, 2);

    // Placeholder occlusion layer. In v0.2 this becomes the real mask/depth layer.
    dcxOcclusionLayer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, b.size.width, b.size.height)];
    dcxOcclusionLayer.backgroundColor = UIColor.clearColor;
    dcxOcclusionLayer.userInteractionEnabled = NO;

    [dcxRoot addSubview:dcxDateLabel];
    [dcxRoot addSubview:dcxClockLabel];
    [dcxRoot addSubview:dcxOcclusionLayer];

    [window addSubview:dcxRoot];
    [window bringSubviewToFront:dcxRoot];
    DCXUpdateClock();
}

static void DCXShow(void) {
    DCXBuildClockIfNeeded();
    if (!dcxRoot) return;
    dcxVisible = YES;
    dcxRoot.hidden = NO;
    dcxRoot.alpha = 1.0;
    [DCXMainWindow() bringSubviewToFront:dcxRoot];
    DCXUpdateClock();

    if (!dcxTimer) {
        dcxTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(__unused NSTimer *timer) {
            DCXUpdateClock();
            DCXHideStockClockViews(DCXMainWindow());
            if (dcxRoot) [DCXMainWindow() bringSubviewToFront:dcxRoot];
        }];
        [[NSRunLoop mainRunLoop] addTimer:dcxTimer forMode:NSRunLoopCommonModes];
    }
}

static void DCXHide(void) {
    dcxVisible = NO;
    if (dcxRoot) dcxRoot.hidden = YES;
}

%hook SBLockScreenManager
- (void)lockUIFromSource:(int)arg1 withOptions:(id)arg2 {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DCXShow();
    });
}
- (void)unlockUIFromSource:(int)arg1 withOptions:(id)arg2 {
    DCXHide();
    %orig;
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // If installed while locked/respringed, show base clock safely.
        DCXShow();
    });
}
%end

%hook UIView
- (void)didMoveToWindow {
    %orig;
    if (!dcxVisible) return;
    NSString *className = NSStringFromClass([self class]);
    if ([className rangeOfString:@"DateView" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [className rangeOfString:@"TimeView" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [className rangeOfString:@"Clock" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        if (self != dcxRoot && ![self isDescendantOfView:dcxRoot]) {
            self.hidden = YES;
            self.alpha = 0.0;
        }
    }
}
%end

%ctor {
    @autoreleasepool {
        NSLog(@"[DepthClockXI] Loaded v0.1.0");
    }
}
