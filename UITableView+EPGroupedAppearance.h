//
//  UITableView+EPGroupedAppearance.h
//  EPGroupedTableViewApperance
//
//  Created by EXphinx on 13-10-12.
//  Copyright (c) 2013年 EXphinx. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, EPGroupedTableViewCellPosition) {
    kEPGroupedTableViewCellPositionUndefined = 0,
    kEPGroupedTableViewCellPositionTop,
    kEPGroupedTableViewCellPositionMiddle,
    kEPGroupedTableViewCellPositionBottom,
    kEPGroupedTableViewCellPositionTopBottom,
};

typedef void(^EPGroupedTableViewCellStylingBlock)(UITableViewCell *cell, EPGroupedTableViewCellPosition position);

@interface UITableView (EPGroupedAppearance)

+ (instancetype)appearanceProxy;

@property (nonatomic, copy) EPGroupedTableViewCellStylingBlock stylingBlock;

@end

@interface UIView (EPGroupedAppearance)

- (void)makeSubviewsBackgroundColorClear;

@end