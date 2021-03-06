/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import <ReactABI17_0_0/ABI17_0_0RCTComponent.h>

@class ABI17_0_0RCTEventDispatcher;

@interface ABI17_0_0RCTTextField : UITextField

@property (nonatomic, assign) BOOL caretHidden;
@property (nonatomic, assign) BOOL selectTextOnFocus;
@property (nonatomic, assign) BOOL blurOnSubmit;
@property (nonatomic, assign) UIEdgeInsets contentInset;
@property (nonatomic, strong) UIColor *placeholderTextColor;
@property (nonatomic, assign) NSInteger mostRecentEventCount;
@property (nonatomic, strong) NSNumber *maxLength;

@property (nonatomic, copy) ABI17_0_0RCTDirectEventBlock onSelectionChange;

- (instancetype)initWithEventDispatcher:(ABI17_0_0RCTEventDispatcher *)eventDispatcher NS_DESIGNATED_INITIALIZER;

@end
