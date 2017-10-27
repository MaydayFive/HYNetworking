//
//  HYBatchContinueRequestAgent.m
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/17.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import "HYBatchContinueRequestAgent.h"
#import "HYBatchContinueRequest.h"

@interface HYBatchContinueRequestAgent()

@property (strong, nonatomic) NSMutableArray<HYBatchContinueRequest *> *requestArray;

@end

@implementation HYBatchContinueRequestAgent

+ (HYBatchContinueRequestAgent *)sharedAgent
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _requestArray = [NSMutableArray array];
    }
    return self;
}

- (void)addBatchRequest:(HYBatchContinueRequest *)request
{
    @synchronized(self) {
        [_requestArray addObject:request];
    }
}

- (void)removeBatchRequest:(HYBatchContinueRequest *)request
{
    @synchronized(self) {
        [_requestArray removeObject:request];
    }
}

@end
