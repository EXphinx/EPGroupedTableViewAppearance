//
//  UITableView+EPGroupedAppearance.m
//  EPGroupedTableViewApperance
//
//  Created by EXphinx on 13-10-12.
//  Copyright (c) 2013年 EXphinx. All rights reserved.
//

#import "UITableView+EPGroupedAppearance.h"
#import <objc/runtime.h>

@interface EPTableViewDelegateInterceptor : NSObject
@property (nonatomic, weak) id receiver;
@property (nonatomic, weak) id middleMan;
@property (nonatomic, strong, readonly) NSSet *respondsSelectorStrings;
- (id)initWithRespondsSelectorStrings:(NSSet *)selStrings;
@end

@implementation UITableView (EPGroupedAppearance)

#pragma mark -
#pragma mark Associated Objects

- (void)setStylingBlock:(EPGroupedTableViewCellStylingBlock)stylingBlock {
    objc_setAssociatedObject(self, @selector(stylingBlock), stylingBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (EPGroupedTableViewCellStylingBlock)stylingBlock {
    EPGroupedTableViewCellStylingBlock block = objc_getAssociatedObject(self, @selector(stylingBlock));
    return block ? block : [[[self class] appearanceProxy] stylingBlock];
}

+ (instancetype)appearanceProxy {
    static UITableView *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UITableView alloc] init];
    });
    return instance;
}

#pragma mark -
#pragma mark Delegate Interceptor

- (EPTableViewDelegateInterceptor *)delegateProxy {
    EPTableViewDelegateInterceptor *proxy = objc_getAssociatedObject(self, @selector(delegateProxy));
    if (!proxy) {
        proxy = [self configuredDelegateProxy];
        objc_setAssociatedObject(self, @selector(delegateProxy), proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return proxy;
}

- (EPTableViewDelegateInterceptor *)configuredDelegateProxy {
    
    //check enabled options, fill respondsSelectors
    NSMutableSet *newRespondsSelectorStrings = [NSMutableSet set];
    [newRespondsSelectorStrings unionSet:[self groupedCellStylingDelegateSelectors]];
    //reset self's delegate to toggle recheck 'responsToXXX'
    EPTableViewDelegateInterceptor *aNewProxy = [[EPTableViewDelegateInterceptor alloc] initWithRespondsSelectorStrings:newRespondsSelectorStrings];
    
    [aNewProxy setMiddleMan:self];
    return aNewProxy;
}

#pragma mark -
#pragma mark Load

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[self class] ep_swapSelector:@selector(original_setDelegate:) withSelector:@selector(setDelegate:)];
    });
}

#pragma mark -
#pragma mark Swizzle Methods

+ (void)ep_swapSelector:(SEL)aOriginalSelector withSelector:(SEL)aSwappedSelector {
    
    Method originalMethod = class_getInstanceMethod(self, aOriginalSelector);
    Method swappedMethod = class_getInstanceMethod(self, aSwappedSelector);
    
    class_addMethod(self, aOriginalSelector,
                    class_getMethodImplementation(self, aOriginalSelector),
                    method_getTypeEncoding(originalMethod));
    
    class_addMethod(self, aSwappedSelector,
                    class_getMethodImplementation(self, aSwappedSelector),
                    method_getTypeEncoding(swappedMethod));
    
    method_exchangeImplementations(originalMethod, swappedMethod);
}

- (id)original_delegate {
    return [[self delegateProxy] receiver];
}

- (void)original_setDelegate:(id)delegate {
    
    [self original_setDelegate:nil];
    [[self delegateProxy] setReceiver:delegate];
    [self original_setDelegate:[self delegateProxy]];
}

#pragma mark -
#pragma mark Apply Style

- (EPGroupedTableViewCellPosition)cellPosiotionForCellAtRow:(NSUInteger)row numberOfRows:(NSUInteger)numberOfRows {
    
    if (numberOfRows == 0) {
        return kEPGroupedTableViewCellPositionUndefined;
    }
    else if (numberOfRows == 1) {
        return kEPGroupedTableViewCellPositionTopBottom;
    }
    if (row == 0) {
        return kEPGroupedTableViewCellPositionTop;
    }
    else if (row == numberOfRows - 1) {
        return kEPGroupedTableViewCellPositionBottom;
    }
    return kEPGroupedTableViewCellPositionMiddle;
}

- (void)updateGroupedStyleCell:(UITableViewCell *)cell atRow:(NSUInteger)row numberOfRows:(NSUInteger)numberOfRows {
    
    if (self.stylingBlock) {
        self.stylingBlock(cell, [self cellPosiotionForCellAtRow:row numberOfRows:numberOfRows]);
    }
}

#pragma mark -
#pragma mark Delegate Methods Intercept

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (tableView.style == UITableViewStyleGrouped) {
        //call this is safe.
        [tableView updateGroupedStyleCell:cell atRow:indexPath.row
                             numberOfRows:[[tableView dataSource] tableView:tableView numberOfRowsInSection:indexPath.section]];
        
    }
    if ([[tableView original_delegate] respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [[tableView original_delegate] tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
}

- (NSSet *)groupedCellStylingDelegateSelectors {
    return [NSSet setWithObjects:NSStringFromSelector(@selector(tableView:willDisplayCell:forRowAtIndexPath:)), nil];
}

@end


@interface EPTableViewDelegateInterceptor ()
@property (nonatomic, strong) NSSet *respondsSelectorStrings;
@end
@implementation EPTableViewDelegateInterceptor

- (id)initWithRespondsSelectorStrings:(NSSet *)selStrings {
    self = [super init];
    if (self) {
        _respondsSelectorStrings = [selStrings copy];
    }
    return self;
}

- (void)addSelectorStrings:(NSSet *)selStrings {
    
    if (_respondsSelectorStrings) {
        self.respondsSelectorStrings = [_respondsSelectorStrings setByAddingObjectsFromSet:selStrings];
    }
    else {
        self.respondsSelectorStrings = [selStrings copy];
    }
}

- (BOOL)canMiddleManRespondToSelector:(SEL)aSelector {
    NSString *selString = NSStringFromSelector(aSelector);
    return [self.respondsSelectorStrings containsObject:selString];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    
    //only forward selectors in respondsSelectorStrings to _middleMan
    if ([self canMiddleManRespondToSelector:aSelector] &&
        [_middleMan respondsToSelector:aSelector]) {
        return _middleMan;
    }
    
    // if ([_middleMan respondsToSelector:aSelector]) { return _middleMan; }
    if ([_receiver respondsToSelector:aSelector]) { return _receiver; }
    return [super forwardingTargetForSelector:aSelector];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    
    //only forward selectors in respondsSelectorStrings to _middleMan
    if ([self canMiddleManRespondToSelector:aSelector] &&
        [_middleMan respondsToSelector:aSelector]) {
        return YES;
    }
    if ([_receiver respondsToSelector:aSelector]) { return YES; }
    return [super respondsToSelector:aSelector];
}

@end

@implementation UIView (EPGroupedAppearance)

- (void)makeSubviewsBackgroundColorClear {
    
    for (UIView *subview in self.subviews) {
        subview.backgroundColor = [UIColor clearColor];
        [subview makeSubviewsBackgroundColorClear];
    }
}

@end
