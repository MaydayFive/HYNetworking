//
//  HYChainRequest.m
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/16.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import "HYChainRequest.h"
#import "HYChainRequestAgent.h"
#import "HYNetworkPrivate.h"
#import "HYBaseRequest.h"

@interface HYChainRequest()<HYRequestDelegate>

@property (nonatomic, strong) NSMutableArray<HYBaseRequest *> *requestArray;
@property (nonatomic, strong) NSMutableArray<HYChainCallback> *requestCallbackArray;
@property (nonatomic, assign) NSUInteger nextRequestIndex;
@property (nonatomic, strong) HYChainCallback emptyCallback;

@end

@implementation HYChainRequest

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _nextRequestIndex = 0;
        _requestArray = [NSMutableArray array];
        _requestCallbackArray = [NSMutableArray array];
        _emptyCallback = ^(HYChainRequest *chainRequest, HYBaseRequest *baseRequest) {
            //空白回调
        };
    }
    return self;
}

- (void)start
{
    if (_nextRequestIndex > 0)
    {
        NSLog(@"Error! Chain request has already started.");
        return;
    }
    
    if ([_requestArray count] > 0)
    {
        [self startNextRequest];
        [[HYChainRequestAgent sharedAgent] addChainRequest:self];
    }
    else
    {
        NSLog(@"Error! Chain request array is empty.");
    }
}

- (void)stop
{
    [self clearRequest];
    [[HYChainRequestAgent sharedAgent] removeChainRequest:self];
}

- (BOOL)startNextRequest
{
    if (_nextRequestIndex < [_requestArray count])
    {
        HYBaseRequest *request = _requestArray[_nextRequestIndex];
        _nextRequestIndex++;
        request.delegate = self;
        //单个request 的回调统一为HYChainCallback，不需要自己的回调
        [request clearCompletionBlock];
        [request start];
        return YES;
    }
    else
    {
        return NO;
    }
}

- (void)clearRequest
{
    NSUInteger currentRequestIndex = _nextRequestIndex - 1;
    if (currentRequestIndex < [_requestArray count])
    {
        HYBaseRequest *request = _requestArray[currentRequestIndex];
        //停止当前的请求
        [request stop];
    }
    [_requestArray removeAllObjects];
    [_requestCallbackArray removeAllObjects];
}

- (void)addRequest:(HYBaseRequest *)request callback:(HYChainCallback)callback
{
    [_requestArray addObject:request];
    if (callback != nil)
    {
        [_requestCallbackArray addObject:callback];
    }
    else
    {
        [_requestCallbackArray addObject:_emptyCallback];
    }
}

#pragma mark - HYRequestDelegate

- (void)requestFinished:(__kindof HYBaseRequest *)request
{
    NSUInteger currentRequestIndex = _nextRequestIndex - 1;
    HYChainCallback callback = _requestCallbackArray[currentRequestIndex];
    callback(self, request);
    if (![self startNextRequest])
    {
        if ([_delegate respondsToSelector:@selector(chainRequestFinished:)])
        {
            [_delegate chainRequestFinished:self];
            [[HYChainRequestAgent sharedAgent] removeChainRequest:self];
        }
    }
}

- (void)requestFailed:(__kindof HYBaseRequest *)request
{
    if ([_delegate respondsToSelector:@selector(chainRequestFailed:failedBaseRequest:)])
    {
        //有 request 失败的话。就返回失败的request，并停止这次chain调用（不再调用startNextRequest）
        [_delegate chainRequestFailed:self failedBaseRequest:request];
        [[HYChainRequestAgent sharedAgent] removeChainRequest:self];
    }
}

- (NSArray<HYBaseRequest *> *)requestArray
{
    return _requestArray;
}


@end
