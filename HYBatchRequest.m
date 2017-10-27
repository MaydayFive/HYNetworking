//
//  HYBatchRequest.m
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/17.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import "HYBatchRequest.h"
#import "HYNetworkPrivate.h"
#import "HYBatchRequestAgent.h"
#import "HYRequest.h"

@interface HYBatchRequest() <HYRequestDelegate>

@property (nonatomic) NSInteger finishedCount;

@end

@implementation HYBatchRequest

- (instancetype)initWithRequestArray:(NSArray<HYRequest *> *)requestArray
{
    self = [super init];
    if (self)
    {
        _requestArray = [requestArray copy];
        _finishedCount = 0;
        for (HYRequest * req in _requestArray)
        {
            if (![req isKindOfClass:[HYRequest class]])
            {
                NSLog(@"Error, request item must be YTKRequest instance.");
                return nil;
            }
        }
    }
    return self;
}

- (void)start
{
    if (_finishedCount > 0)
    {
        NSLog(@"Error! Batch request has already started.");
        return;
    }
    _failedRequest = nil;
//    [[HYBatchRequestAgent sharedAgent] addBatchRequest:self];
    for (HYRequest * req in _requestArray)
    {
        req.delegate = self;
        //单个request 的回调统一为BatchCallback，不需要自己的回调
        [req clearCompletionBlock];
        [req start];
    }
}

- (void)stop
{
    _delegate = nil;
    [self clearRequest];
//    [[HYBatchRequestAgent sharedAgent] removeBatchRequest:self];
}

- (void)clearRequest
{
    for (HYRequest * req in _requestArray)
    {
        [req stop];
    }
    [self clearCompletionBlock];
}

- (void)startWithCompletionBlockWithSuccess:(void (^)(HYBatchRequest *batchRequest))success
                                    failure:(void (^)(HYBatchRequest *batchRequest))failure
{
    [self setCompletionBlockWithSuccess:success failure:failure];
    [self start];
}

- (void)setCompletionBlockWithSuccess:(void (^)(HYBatchRequest *batchRequest))success
                              failure:(void (^)(HYBatchRequest *batchRequest))failure
{
    self.successCompletionBlock = success;
    self.failureCompletionBlock = failure;
}

- (void)clearCompletionBlock
{
    // nil out to break the retain cycle.
    self.successCompletionBlock = nil;
    self.failureCompletionBlock = nil;
}

- (BOOL)isDataFromCache
{
    BOOL result = YES;
    for (HYRequest *request in _requestArray)
    {
        if (!request.isDataFromCache)
        {
            result = NO;
        }
    }
    return result;
}


- (void)dealloc {
    [self clearRequest];
}

#pragma mark - HYRequestDelegate

- (void)requestFinished:(HYRequest *)request
{
    _finishedCount++;
    if (_finishedCount == _requestArray.count)
    {
        if ([_delegate respondsToSelector:@selector(batchRequestFinished:)]) {
            [_delegate batchRequestFinished:self];
        }
        if (_successCompletionBlock)
        {
            _successCompletionBlock(self);
        }
        [self clearCompletionBlock];
        
        [[HYBatchRequestAgent sharedAgent] removeBatchRequest:self];
    }
}

- (void)requestFailed:(HYRequest *)request
{
    _failedRequest = request;
    // 全部停止
    for (HYRequest *req in _requestArray)
    {
        [req stop];
    }
    // Callback
    if ([_delegate respondsToSelector:@selector(batchRequestFailed:)])
    {
        [_delegate batchRequestFailed:self];
    }
    if (_failureCompletionBlock)
    {
        _failureCompletionBlock(self);
    }
    // Clear
    [self clearCompletionBlock];
    
    [[HYBatchRequestAgent sharedAgent] removeBatchRequest:self];
}

@end
