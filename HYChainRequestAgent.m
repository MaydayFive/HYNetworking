//
//  HYChainRequestAgent.m
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/16.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import "HYChainRequestAgent.h"
#import "HYChainRequest.h"

@interface HYChainRequestAgent()

@property (strong, nonatomic) NSMutableArray<HYChainRequest *> *requestArray;

@end

@implementation HYChainRequestAgent

+ (HYChainRequestAgent *)sharedAgent
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

- (void)addChainRequest:(HYChainRequest *)request
{
    @synchronized(self) {
        [_requestArray addObject:request];
    }
}

- (void)removeChainRequest:(HYChainRequest *)request
{
    @synchronized(self) {
        [_requestArray removeObject:request];
    }
}

@end
