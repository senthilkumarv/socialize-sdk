//
//  SocializeLikeButton.m
//  SocializeSDK
//
//  Created by Nathaniel Griswold on 4/16/12.
//  Copyright (c) 2012 Socialize, Inc. All rights reserved.
//

#import "SocializeLikeButton.h"
#import "SocializeUserService.h"
#import "SocializeEntityService.h"
#import "SocializeLikeService.h"
#import "NSTimer+BlocksKit.h"

static NSTimeInterval SocializeLikeButtonRecoveryTimerInterval = 5.0;

@interface SocializeLikeButton ()

@property (nonatomic, assign) SocializeRequestState likeGetRequestState;
@property (nonatomic, assign) SocializeRequestState entityCreateRequestState;
@property (nonatomic, assign) SocializeRequestState likeCreateRequestState;
@property (nonatomic, assign) SocializeRequestState likeDeleteRequestState;

@property (nonatomic, retain) id<SocializeLike> like;
@property (nonatomic, retain) NSTimer *recoveryTimer;

@end

@implementation SocializeLikeButton
@synthesize actualButton = actualButton_;
@synthesize disabledImage = disabledImage_;
@synthesize inactiveImage = inactiveImage_;
@synthesize inactiveHighlightedImage = inactiveHighlightedImage_;
@synthesize activeImage = activeImage_;
@synthesize activeHighlightedImage = activeHighlightedImage_;
@synthesize likeIcon = likeIcon_;
@synthesize entity = entity_;
@synthesize socialize = socialize_;
@synthesize like = like_;
@synthesize recoveryTimer = recoveryTimer_;

@synthesize initialized = initialized_;

@synthesize likeGetRequestState = likeGetRequestState_;
@synthesize likeCreateRequestState = likeCreateRequestState_;
@synthesize likeDeleteRequestState = likeDeleteRequestState_;
@synthesize entityCreateRequestState = entityCreateRequestState_;

- (void)dealloc {
    self.actualButton = nil;
    self.disabledImage = nil;
    self.inactiveImage = nil;
    self.inactiveHighlightedImage = nil;
    self.activeImage = nil;
    self.activeHighlightedImage = nil;
    self.like = nil;
    
    if (recoveryTimer_ != nil) {
        [recoveryTimer_ invalidate];
    }
    self.recoveryTimer = nil;
    
    [super dealloc];
}

- (id)initWithFrame:(CGRect)frame entity:(id<SocializeEntity>)entity {
    self = [super initWithFrame:frame];
    if (self) {
        [self configureButtonBackgroundImages];
        
        self.entity = entity;
        
        self.actualButton.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [self addSubview:self.actualButton];
        
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)attemptRecovery {
    if (!self.initialized) {
        [self tryToFinishInitializing];
    } else if (self.likeCreateRequestState == SocializeRequestStateFailed) {
        [self likeOnServer];
    } else if (self.likeDeleteRequestState == SocializeRequestStateFailed) {
        [self unlikeOnServer];
    } else {
        [self stopRecoveryTimer];
    }
}

- (void)startRecoveryTimer {
    if (self.recoveryTimer == nil) {
        __block __typeof__(self) weakSelf = self;
        self.recoveryTimer = [NSTimer scheduledTimerWithTimeInterval:SocializeLikeButtonRecoveryTimerInterval
                                                               block:^(NSTimeInterval interval) {
                                                                   [weakSelf attemptRecovery];
                                                               } repeats:YES];
    }
}

- (void)stopRecoveryTimer {
    if (self.recoveryTimer != nil) {
        [self.recoveryTimer invalidate];
        self.recoveryTimer = nil;
    }
}

- (BOOL)liked {
    return self.like != nil;
}

- (Socialize*)socialize {
    if (socialize_ == nil) {
        socialize_ = [[Socialize alloc] initWithDelegate:self];
    }
    return socialize_;
}

- (void)getLikeFromServer {
    self.likeGetRequestState = SocializeRequestStateSent;
    [self.socialize getLikesForUser:[self.socialize authenticatedUser] entity:self.entity first:nil last:[NSNumber numberWithInteger:1]];
}

- (void)createEntityOnServer {
    self.entityCreateRequestState = SocializeRequestStateSent;
    [self.socialize createEntity:self.entity];
}

- (void)tryToFinishInitializing {
    if (self.initialized) {
        return;
    }
    
    if (self.likeGetRequestState <= SocializeRequestStateNotStarted) {
        [self getLikeFromServer];
        return;
    } else if (self.likeGetRequestState < SocializeRequestStateFinished) {
        // Still waiting for response
        return;
    }
    
    if (self.like == nil) {
        // Could not fetch an existing like from server -- we need to get the entity
        
        if (self.entityCreateRequestState <= SocializeRequestStateNotStarted) {
            // We know the entity is not liked. Just make sure the entity exists.
            [self createEntityOnServer];
            return;
        } else if (self.entityCreateRequestState < SocializeRequestStateFinished) {
            // Still waiting for entity -- initialization not complete
            return;
        }
    } 

    [self stopRecoveryTimer];
    self.initialized = YES;
    [self configureButtonBackgroundImages];
    self.actualButton.enabled = YES;
}

- (void)service:(SocializeService *)service didFetchElements:(NSArray *)dataArray {
    if ([service isKindOfClass:[SocializeUserService class]]) {
        // Get likes for user
        if ([dataArray count] > 0) {
            self.like = [dataArray objectAtIndex:0];
            self.entity = self.like.entity;
        } else {
            // the like did not exist, which is ok. Continue on, anyway
        }
        
        self.likeGetRequestState = SocializeRequestStateFinished;
        [self tryToFinishInitializing];
        
    }
}

- (void)service:(SocializeService *)service didCreate:(id)objectOrObjects {
    if ([service isKindOfClass:[SocializeEntityService class]]) {
        self.entity = objectOrObjects;
        self.entityCreateRequestState = SocializeRequestStateFinished;
        [self tryToFinishInitializing];
    } else if ([service isKindOfClass:[SocializeLikeService class]]) {
        // Like has been successfully created
        self.likeCreateRequestState = SocializeRequestStateFinished;
        self.like = objectOrObjects;
        self.actualButton.enabled = YES;
        [self configureButtonBackgroundImages];
    }
}

- (void)service:(SocializeService *)service didDelete:(id<SocializeObject>)object {
    if ([service isKindOfClass:[SocializeLikeService class]]) {
        self.likeDeleteRequestState = SocializeRequestStateFinished;
        self.like = nil;
        self.actualButton.enabled = YES;
        [self configureButtonBackgroundImages];
    }
}

- (void)service:(SocializeService *)service didFail:(NSError *)error {
    if ([service isKindOfClass:[SocializeUserService class]]) {
        self.likeGetRequestState = SocializeRequestStateFailed;
    } else if ([service isKindOfClass:[SocializeEntityService class]]) {
        self.entityCreateRequestState = SocializeRequestStateFailed;
    } else if ([service isKindOfClass:[SocializeLikeService class]]) {
        if (self.likeCreateRequestState == SocializeRequestStateSent) {
            self.likeCreateRequestState = SocializeRequestStateFailed;
        } else if (self.likeDeleteRequestState == SocializeRequestStateSent) {
            self.likeDeleteRequestState = SocializeRequestStateFailed;
        }
    }
    
    [self startRecoveryTimer];
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    self.actualButton.enabled = NO;
    [self tryToFinishInitializing];
}

+ (UIImage*)defaultDisabledImage {
    return nil;
}

+ (UIImage*)defaultInactiveImage {
    return [[UIImage imageNamed:@"action-bar-button-black.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
}

+ (UIImage*)defaultInactiveHighlightedImage {
    return [[UIImage imageNamed:@"action-bar-button-black-hover.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
}

+ (UIImage*)defaultActiveImage {
    return [[UIImage imageNamed:@"action-bar-button-red.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
}

+ (UIImage*)defaultActiveHighlightedImage {
    return [[UIImage imageNamed:@"action-bar-button-red-hover.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
}

+ (UIImage*)defaultLikeIcon {
    return [UIImage imageNamed:@"action-bar-icon-like.png"];
}

- (void)setLikeIcon:(UIImage*)likeIcon {
    NonatomicRetainedSetToFrom(likeIcon_, likeIcon);
    [self configureButtonBackgroundImages];
}

- (UIImage*)likeIcon {
    if (likeIcon_ == nil) {
        likeIcon_ = [[[self class] defaultLikeIcon] retain];
    }
    
    return likeIcon_;
}

- (UIImage*)disabledImage {
    if (disabledImage_ == nil) {
        disabledImage_ = [[[self class] defaultDisabledImage] retain];
    }
    
    return disabledImage_;
}

- (void)setDisabledImage:(UIImage *)disabledImage {
    NonatomicCopySetToFrom(disabledImage_, disabledImage);
    [self configureButtonBackgroundImages];
}

- (UIImage*)inactiveImage {
    if (inactiveImage_ == nil) {
        inactiveImage_ = [[[self class] defaultInactiveImage] retain];
    }
    
    return inactiveImage_;
}

- (void)setInactiveImage:(UIImage *)inactiveImage {
    NonatomicCopySetToFrom(inactiveImage_, inactiveImage);
    [self configureButtonBackgroundImages];
}

- (UIImage*)inactiveHighlightedImage {
    if (inactiveHighlightedImage_ == nil) {
        inactiveHighlightedImage_ = [[[self class] defaultInactiveHighlightedImage] retain];
    }
    
    return inactiveHighlightedImage_;
}

- (void)setInactiveHighlightedImage:(UIImage *)inactiveHighlightedImage {
    NonatomicCopySetToFrom(inactiveHighlightedImage_, inactiveHighlightedImage);
    [self configureButtonBackgroundImages];
}

- (UIImage*)activeImage {
    if (activeImage_ == nil) {
        activeImage_ = [[[self class] defaultActiveImage] retain];
    }
    
    return activeImage_;
}

- (void)setActiveImage:(UIImage *)activeImage {
    NonatomicCopySetToFrom(activeImage_, activeImage);
    [self configureButtonBackgroundImages];
}

- (UIImage*)activeHighlightedImage {
    if (activeHighlightedImage_ == nil) {
        activeHighlightedImage_ = [[[self class] defaultActiveHighlightedImage] retain];
    }
    
    return activeHighlightedImage_;
}

- (void)setActiveHighlightedImage:(UIImage *)activeHighlightedImage {
    NonatomicCopySetToFrom(activeHighlightedImage_, activeHighlightedImage);
    [self configureButtonBackgroundImages];
}

- (void)configureButtonBackgroundImages {
    [self.actualButton setBackgroundImage:self.disabledImage forState:UIControlStateDisabled];
    
    if (self.like != nil) {
        [self.actualButton setBackgroundImage:self.activeImage forState:UIControlStateNormal];
        [self.actualButton setBackgroundImage:self.activeHighlightedImage forState:UIControlStateHighlighted];
    } else {
        [self.actualButton setBackgroundImage:self.inactiveImage forState:UIControlStateNormal];
        [self.actualButton setBackgroundImage:self.inactiveHighlightedImage forState:UIControlStateHighlighted];        
    }
    
    [self.actualButton setImage:self.likeIcon forState:UIControlStateNormal];
}

- (UIButton*)actualButton {
    if (actualButton_ == nil) {
        actualButton_ = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        actualButton_.accessibilityLabel = @"like button";
        actualButton_.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
        [actualButton_ addTarget:self action:@selector(actualButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return actualButton_;
}

- (void)unlikeOnServer {
    if (self.likeDeleteRequestState != SocializeRequestStateSent) {
        self.likeDeleteRequestState = SocializeRequestStateSent;
        [self.socialize unlikeEntity:self.like];
    }
}

- (void)likeOnServer {
    if (self.likeCreateRequestState != SocializeRequestStateSent) {
        self.likeCreateRequestState = SocializeRequestStateSent;
        [self.socialize likeEntityWithKey:self.entity.key longitude:nil latitude:nil];
    }
}

- (void)toggleLikeState {
    if (self.like == nil) {
        [self likeOnServer];
    } else {
        [self unlikeOnServer];
    }
}

- (void)actualButtonPressed:(UIButton*)button {
    self.actualButton.enabled = NO;
    [self toggleLikeState];
}

- (void)initializeActualButton {
}

@end
