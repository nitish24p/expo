/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI17_0_0RCTRedBox.h"

#import "ABI17_0_0RCTBridge.h"
#import "ABI17_0_0RCTConvert.h"
#import "ABI17_0_0RCTDefines.h"
#import "ABI17_0_0RCTErrorInfo.h"
#import "ABI17_0_0RCTJSStackFrame.h"
#import "ABI17_0_0RCTUtils.h"

#if ABI17_0_0RCT_DEV

@class ABI17_0_0RCTRedBoxWindow;

@protocol ABI17_0_0RCTRedBoxWindowActionDelegate <NSObject>

- (void)redBoxWindow:(ABI17_0_0RCTRedBoxWindow *)redBoxWindow openStackFrameInEditor:(ABI17_0_0RCTJSStackFrame *)stackFrame;
- (void)reloadFromRedBoxWindow:(ABI17_0_0RCTRedBoxWindow *)redBoxWindow;

@end

@interface ABI17_0_0RCTRedBoxWindow : UIWindow <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, weak) id<ABI17_0_0RCTRedBoxWindowActionDelegate> actionDelegate;
@end

@implementation ABI17_0_0RCTRedBoxWindow
{
  UITableView *_stackTraceTableView;
  NSString *_lastErrorMessage;
  NSArray<ABI17_0_0RCTJSStackFrame *> *_lastStackTrace;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    self.windowLevel = UIWindowLevelAlert + 1000;
    self.backgroundColor = [UIColor colorWithRed:0.8 green:0 blue:0 alpha:1];
    self.hidden = YES;

    UIViewController *rootController = [UIViewController new];
    self.rootViewController = rootController;
    UIView *rootView = rootController.view;
    rootView.backgroundColor = [UIColor clearColor];

    const CGFloat buttonHeight = 60;

    CGRect detailsFrame = rootView.bounds;
    detailsFrame.size.height -= buttonHeight;

    _stackTraceTableView = [[UITableView alloc] initWithFrame:detailsFrame style:UITableViewStylePlain];
    _stackTraceTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _stackTraceTableView.delegate = self;
    _stackTraceTableView.dataSource = self;
    _stackTraceTableView.backgroundColor = [UIColor clearColor];
#if !TARGET_OS_TV
    _stackTraceTableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.3];
    _stackTraceTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
#endif
    _stackTraceTableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [rootView addSubview:_stackTraceTableView];

  #if TARGET_OS_SIMULATOR
    NSString *reloadText = @"Reload JS (\u2318R)";
    NSString *dismissText = @"Dismiss (ESC)";
    NSString *copyText = @"Copy (\u2325\u2318C)";
  #else
    NSString *reloadText = @"Reload JS";
    NSString *dismissText = @"Dismiss";
    NSString *copyText = @"Copy";
  #endif

    UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
    dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
    dismissButton.accessibilityIdentifier = @"redbox-dismiss";
    dismissButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [dismissButton setTitle:dismissText forState:UIControlStateNormal];
    [dismissButton setTitleColor:[UIColor colorWithWhite:1 alpha:0.5] forState:UIControlStateNormal];
    [dismissButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [dismissButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];

    UIButton *reloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
    reloadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    reloadButton.accessibilityIdentifier = @"redbox-reload";
    reloadButton.titleLabel.font = [UIFont systemFontOfSize:14];

    [reloadButton setTitle:reloadText forState:UIControlStateNormal];
    [reloadButton setTitleColor:[UIColor colorWithWhite:1 alpha:0.5] forState:UIControlStateNormal];
    [reloadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [reloadButton addTarget:self action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];

    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    copyButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    copyButton.accessibilityIdentifier = @"redbox-copy";
    copyButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [copyButton setTitle:copyText forState:UIControlStateNormal];
    [copyButton setTitleColor:[UIColor colorWithWhite:1 alpha:0.5] forState:UIControlStateNormal];
    [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [copyButton addTarget:self action:@selector(copyStack) forControlEvents:UIControlEventTouchUpInside];

    CGFloat buttonWidth = self.bounds.size.width / 3;
    dismissButton.frame = CGRectMake(0, self.bounds.size.height - buttonHeight, buttonWidth, buttonHeight);
    reloadButton.frame = CGRectMake(buttonWidth, self.bounds.size.height - buttonHeight, buttonWidth, buttonHeight);
    copyButton.frame = CGRectMake(buttonWidth * 2, self.bounds.size.height - buttonHeight, buttonWidth, buttonHeight);
    [rootView addSubview:dismissButton];
    [rootView addSubview:reloadButton];
    [rootView addSubview:copyButton];
  }
  return self;
}

ABI17_0_0RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)aDecoder)

- (void)dealloc
{
  _stackTraceTableView.dataSource = nil;
  _stackTraceTableView.delegate = nil;
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showErrorMessage:(NSString *)message withStack:(NSArray<ABI17_0_0RCTJSStackFrame *> *)stack isUpdate:(BOOL)isUpdate
{
  // Show if this is a new message, or if we're updating the previous message
  if ((self.hidden && !isUpdate) || (!self.hidden && isUpdate && [_lastErrorMessage isEqualToString:message])) {
    _lastStackTrace = stack;
    // message is displayed using UILabel, which is unable to render text of
    // unlimited length, so we truncate it
    _lastErrorMessage = [message substringToIndex:MIN((NSUInteger)10000, message.length)];

    [_stackTraceTableView reloadData];

    if (self.hidden) {
      [_stackTraceTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                  atScrollPosition:UITableViewScrollPositionTop
                                          animated:NO];
    }

    [self makeKeyAndVisible];
    [self becomeFirstResponder];
  }
}

- (void)dismiss
{
  self.hidden = YES;
  [self resignFirstResponder];
  [ABI17_0_0RCTSharedApplication().delegate.window makeKeyWindow];
}

- (void)reload
{
  [_actionDelegate reloadFromRedBoxWindow:self];
}

- (void)copyStack
{
  NSMutableString *fullStackTrace;

  if (_lastErrorMessage != nil) {
    fullStackTrace = [_lastErrorMessage mutableCopy];
    [fullStackTrace appendString:@"\n\n"];
  }
  else {
    fullStackTrace = [NSMutableString string];
  }

  for (ABI17_0_0RCTJSStackFrame *stackFrame in _lastStackTrace) {
    [fullStackTrace appendString:[NSString stringWithFormat:@"%@\n", stackFrame.methodName]];
    if (stackFrame.file) {
      [fullStackTrace appendFormat:@"    %@\n", [self formatFrameSource:stackFrame]];
    }
  }
#if !TARGET_OS_TV
  UIPasteboard *pb = [UIPasteboard generalPasteboard];
  [pb setString:fullStackTrace];
#endif
}

- (NSString *)formatFrameSource:(ABI17_0_0RCTJSStackFrame *)stackFrame
{
  NSString *fileName = ABI17_0_0RCTNilIfNull(stackFrame.file) ? [stackFrame.file lastPathComponent] : @"<unknown file>";
  NSString *lineInfo = [NSString stringWithFormat:@"%@:%zd",
                        fileName,
                        stackFrame.lineNumber];

  if (stackFrame.column != 0) {
    lineInfo = [lineInfo stringByAppendingFormat:@":%zd", stackFrame.column];
  }
  return lineInfo;
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView
{
  return 2;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return section == 0 ? 1 : _lastStackTrace.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == 0) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"msg-cell"];
    return [self reuseCell:cell forErrorMessage:_lastErrorMessage];
  }
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  NSUInteger index = indexPath.row;
  ABI17_0_0RCTJSStackFrame *stackFrame = _lastStackTrace[index];
  return [self reuseCell:cell forStackFrame:stackFrame];
}

- (UITableViewCell *)reuseCell:(UITableViewCell *)cell forErrorMessage:(NSString *)message
{
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"msg-cell"];
    cell.textLabel.accessibilityIdentifier = @"redbox-error";
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = [UIColor whiteColor];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
  }

  cell.textLabel.text = message;

  return cell;
}

- (UITableViewCell *)reuseCell:(UITableViewCell *)cell forStackFrame:(ABI17_0_0RCTJSStackFrame *)stackFrame
{
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    cell.textLabel.textColor = [UIColor colorWithWhite:1 alpha:0.9];
    cell.textLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:14];
    cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:1 alpha:0.7];
    cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:11];
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    cell.backgroundColor = [UIColor clearColor];
    cell.selectedBackgroundView = [UIView new];
    cell.selectedBackgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
  }

  cell.textLabel.text = stackFrame.methodName;
  if (stackFrame.file) {
    cell.detailTextLabel.text = [self formatFrameSource:stackFrame];
  } else {
    cell.detailTextLabel.text = @"";
  }
  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == 0) {
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;

    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:16],
                                 NSParagraphStyleAttributeName: paragraphStyle};
    CGRect boundingRect = [_lastErrorMessage boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:nil];
    return ceil(boundingRect.size.height) + 40;
  } else {
    return 50;
  }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == 1) {
    NSUInteger row = indexPath.row;
    ABI17_0_0RCTJSStackFrame *stackFrame = _lastStackTrace[row];
    [_actionDelegate redBoxWindow:self openStackFrameInEditor:stackFrame];
  }
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Key commands

- (NSArray<UIKeyCommand *> *)keyCommands
{
  // NOTE: We could use ABI17_0_0RCTKeyCommands for this, but since
  // we control this window, we can use the standard, non-hacky
  // mechanism instead

  return @[
    // Dismiss red box
    [UIKeyCommand keyCommandWithInput:UIKeyInputEscape
                       modifierFlags:0
                              action:@selector(dismiss)],

    // Reload
    [UIKeyCommand keyCommandWithInput:@"r"
                       modifierFlags:UIKeyModifierCommand
                              action:@selector(reload)],

    // Copy = Cmd-Option C since Cmd-C in the simulator copies the pasteboard from
    // the simulator to the desktop pasteboard.
    [UIKeyCommand keyCommandWithInput:@"c"
                       modifierFlags:UIKeyModifierCommand | UIKeyModifierAlternate
                              action:@selector(copyStack)]

    ];
}

- (BOOL)canBecomeFirstResponder
{
  return YES;
}

@end

@interface ABI17_0_0RCTRedBox () <ABI17_0_0RCTInvalidating, ABI17_0_0RCTRedBoxWindowActionDelegate>
@end

@implementation ABI17_0_0RCTRedBox
{
  ABI17_0_0RCTRedBoxWindow *_window;
  NSMutableArray<id<ABI17_0_0RCTErrorCustomizer>> *_errorCustomizers;
}

@synthesize bridge = _bridge;

ABI17_0_0RCT_EXPORT_MODULE()

- (void)registerErrorCustomizer:(id<ABI17_0_0RCTErrorCustomizer>)errorCustomizer
{
  dispatch_async(dispatch_get_main_queue(), ^{
    if (!self->_errorCustomizers) {
      self->_errorCustomizers = [NSMutableArray array];
    }
    if (![self->_errorCustomizers containsObject:errorCustomizer]) {
      [self->_errorCustomizers addObject:errorCustomizer];
    }
  });
}

// WARNING: Should only be called from the main thread/dispatch queue.
- (ABI17_0_0RCTErrorInfo *)_customizeError:(ABI17_0_0RCTErrorInfo *)error
{
  ABI17_0_0RCTAssertMainQueue();

  if (!self->_errorCustomizers) {
    return error;
  }
  for (id<ABI17_0_0RCTErrorCustomizer> customizer in self->_errorCustomizers) {
    ABI17_0_0RCTErrorInfo *newInfo = [customizer customizeErrorInfo:error];
    if (newInfo) {
      error = newInfo;
    }
  }
  return error;
}

- (void)showError:(NSError *)error
{
  [self showErrorMessage:error.localizedDescription withDetails:error.localizedFailureReason];
}

- (void)showErrorMessage:(NSString *)message
{
  [self showErrorMessage:message withStack:nil isUpdate:NO];
}

- (void)showErrorMessage:(NSString *)message withDetails:(NSString *)details
{
  NSString *combinedMessage = message;
  if (details) {
    combinedMessage = [NSString stringWithFormat:@"%@\n\n%@", message, details];
  }
  [self showErrorMessage:combinedMessage withStack:nil isUpdate:NO];
}

- (void)showErrorMessage:(NSString *)message withRawStack:(NSString *)rawStack
{
  NSArray<ABI17_0_0RCTJSStackFrame *> *stack = [ABI17_0_0RCTJSStackFrame stackFramesWithLines:rawStack];
  [self showErrorMessage:message withStack:stack isUpdate:NO];
}

- (void)showErrorMessage:(NSString *)message withStack:(NSArray *)stack
{
  [self showErrorMessage:message withStack:stack isUpdate:NO];
}

- (void)updateErrorMessage:(NSString *)message withStack:(NSArray *)stack
{
  [self showErrorMessage:message withStack:stack isUpdate:YES];
}

- (void)showErrorMessage:(NSString *)message withStack:(NSArray<id> *)stack isUpdate:(BOOL)isUpdate
{
  if (![[stack firstObject] isKindOfClass:[ABI17_0_0RCTJSStackFrame class]]) {
    stack = [ABI17_0_0RCTJSStackFrame stackFramesWithDictionaries:stack];
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    if (!self->_window) {
      self->_window = [[ABI17_0_0RCTRedBoxWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
      self->_window.actionDelegate = self;
    }
    ABI17_0_0RCTErrorInfo *errorInfo = [[ABI17_0_0RCTErrorInfo alloc] initWithErrorMessage:message
                                                                   stack:stack];
    errorInfo = [self _customizeError:errorInfo];
    [self->_window showErrorMessage:errorInfo.errorMessage
                          withStack:errorInfo.stack
                           isUpdate:isUpdate];
  });
}

ABI17_0_0RCT_EXPORT_METHOD(dismiss)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self->_window dismiss];
  });
}

- (void)invalidate
{
  [self dismiss];
}

- (void)redBoxWindow:(__unused ABI17_0_0RCTRedBoxWindow *)redBoxWindow openStackFrameInEditor:(ABI17_0_0RCTJSStackFrame *)stackFrame
{
  if (![_bridge.bundleURL.scheme hasPrefix:@"http"]) {
    ABI17_0_0RCTLogWarn(@"Cannot open stack frame in editor because you're not connected to the packager.");
    return;
  }

  NSData *stackFrameJSON = [ABI17_0_0RCTJSONStringify([stackFrame toDictionary], NULL) dataUsingEncoding:NSUTF8StringEncoding];
  NSString *postLength = [NSString stringWithFormat:@"%tu", stackFrameJSON.length];
  NSMutableURLRequest *request = [NSMutableURLRequest new];
  request.URL = [NSURL URLWithString:@"/open-stack-frame" relativeToURL:_bridge.bundleURL];
  request.HTTPMethod = @"POST";
  request.HTTPBody = stackFrameJSON;
  [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

  [[[NSURLSession sharedSession] dataTaskWithRequest:request] resume];
}

- (void)reloadFromRedBoxWindow:(__unused ABI17_0_0RCTRedBoxWindow *)redBoxWindow
{
  [_bridge reload];
  [self dismiss];
}

@end

@implementation ABI17_0_0RCTBridge (ABI17_0_0RCTRedBox)

- (ABI17_0_0RCTRedBox *)redBox
{
  return [self moduleForClass:[ABI17_0_0RCTRedBox class]];
}

@end

#else // Disabled

@implementation ABI17_0_0RCTRedBox

+ (NSString *)moduleName { return nil; }
- (void)registerErrorCustomizer:(id<ABI17_0_0RCTErrorCustomizer>)errorCustomizer {}
- (void)showError:(NSError *)message {}
- (void)showErrorMessage:(NSString *)message {}
- (void)showErrorMessage:(NSString *)message withDetails:(NSString *)details {}
- (void)showErrorMessage:(NSString *)message withRawStack:(NSString *)rawStack {}
- (void)showErrorMessage:(NSString *)message withStack:(NSArray<NSDictionary *> *)stack {}
- (void)updateErrorMessage:(NSString *)message withStack:(NSArray<NSDictionary *> *)stack {}
- (void)showErrorMessage:(NSString *)message withStack:(NSArray<NSDictionary *> *)stack isUpdate:(BOOL)isUpdate {}
- (void)dismiss {}

@end

@implementation ABI17_0_0RCTBridge (ABI17_0_0RCTRedBox)

- (ABI17_0_0RCTRedBox *)redBox { return nil; }

@end

#endif
