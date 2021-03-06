// Copyright 2015-present 650 Industries. All rights reserved.

@import ObjectiveC;

#import "EXRootViewController.h"
#import "EXShellManager.h"
#import <React/RCTRootView.h>

NS_ASSUME_NONNULL_BEGIN

@interface EXRootViewController ()

@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIView *loadingView;

@end

@implementation EXRootViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
  [super viewDidLoad];

  // Display the launch screen behind the React view so that the React view appears to seamlessly load
  NSString *loadingNib = ([EXShellManager sharedInstance].isShell) ? @"LaunchScreenShell" : @"LaunchScreen";
  NSArray *views = [[NSBundle mainBundle] loadNibNamed:loadingNib owner:self options:nil];
  self.loadingView = views.firstObject;
  self.loadingView.layer.zPosition = 1000;
  self.loadingView.frame = self.view.bounds;
  self.loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.view addSubview:self.loadingView];
  
  // The launch screen contains a loading indicator
  // use this instead of the superclass loading indicator
  _loadingIndicator = (UIActivityIndicatorView *)[self.loadingView viewWithTag:1];
}

#pragma mark - Public

- (void)applicationWillEnterForeground
{
  if (!self.isLoading && ![self.contentView isKindOfClass:[RCTRootView class]]) {
    [self loadReactApplication];
  }
}

#pragma mark - Internal

- (void)setIsLoading:(BOOL)isLoading
{
  // don't call super

  if (isLoading) {
    self.loadingView.hidden = NO;
    [_loadingIndicator startAnimating];
  } else {
    self.loadingView.hidden = YES;
    [_loadingIndicator stopAnimating];
  }
}

@end

NS_ASSUME_NONNULL_END
