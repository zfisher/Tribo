//
//  TBTabView.h
//  Tribo
//
//  Created by Carter Allen on 10/29/11.
//  Copyright (c) 2012 The Tribo Authors.
//  See the included License.md file.
//

@protocol TBTabViewDelegate;

@interface TBTabView : NSView
@property (nonatomic, strong) NSArray *titles;
@property (nonatomic, assign) NSUInteger selectedIndex;
@property (nonatomic, unsafe_unretained) IBOutlet id <TBTabViewDelegate> delegate;
@end

@protocol TBTabViewDelegate <NSObject>
- (void)tabView:(TBTabView *)tabView didSelectIndex:(NSUInteger)index;
@end
