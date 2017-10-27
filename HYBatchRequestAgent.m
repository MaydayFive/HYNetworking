//
//  HYBatchRequestAgent.m
//  HYNetworkDemo
//
//  Created by zheng on 2017/8/17.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import "HYBatchRequestAgent.h"
#import "HYBatchRequest.h"

@interface HYBatchRequestAgent()

@property (strong, nonatomic) NSMutableArray<HYBatchRequest *> *requestArray;

@end

@implementation HYBatchRequestAgent

+ (HYBatchRequestAgent *)sharedAgent
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

- (void)addBatchRequest:(HYBatchRequest *)request
{
    @synchronized(self) {
        [_requestArray addObject:request];
    }
}

- (void)removeBatchRequest:(HYBatchRequest *)request
{
    @synchronized(self) {
        [_requestArray removeObject:request];
    }
}

@end

