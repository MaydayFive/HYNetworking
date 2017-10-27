//
//  HYBatchContinueRequest.m
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/17.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import "HYBatchContinueRequest.h"
#import "HYNetworkPrivate.h"
#import "HYBatchContinueRequestAgent.h"
#import "HYRequest.h"

@interface HYBatchContinueRequest() <HYRequestDelegate>

@property (nonatomic) NSInteger finishedCount;

@property (nonatomic) NSInteger failedCount;

@property (nonatomic, readwrite, strong) NSMutableArray *failedRequestArray;

@end

@implementation HYBatchContinueRequest

- (instancetype)initWithRequestArray:(NSArray<HYRequest *> *)requestArray
{
    self = [super init];
    if (self)
    {
        _requestArray = [requestArray copy];
        _failedRequestArray = [NSMutableArray array];
        _finishedCount = 0;
        _failedCount = 0;
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
    if (_finishedCount > 0 || _failedCount > 0)
    {
        NSLog(@"Error! Batch request has already started.");
        return;
    }
    [_failedRequestArray removeAllObjects];
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
    
    [_failedRequestArray removeAllObjects];
    [self clearCompletionBlock];
}

- (void)startWithCompletionBlockWithCompletion:(nullable void (^)(HYBatchContinueRequest *batchRequest))completion
{
    [self setCompletionBlockWithCompletion:completion];
    [self start];
}

- (void)setCompletionBlockWithCompletion:(nullable void (^)(HYBatchContinueRequest *batchRequest))completion
{
    self.completionBlock = completion;
}

- (void)clearCompletionBlock
{
    self.completionBlock = nil;
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


- (void)dealloc
{
    [self clearRequest];
}

#pragma mark - HYRequestDelegate

- (void)requestFinished:(HYRequest *)request
{
    _finishedCount++;
    [self handleRequestDelegateCallBack];
}

- (void)requestFailed:(HYRequest *)request
{
    _failedCount ++;
    
    if ([_delegate respondsToSelector:@selector(batchContinueRequestFailed:failedRequest:)])
    {
        [_delegate batchContinueRequestFailed:self failedRequest:request];
    }
    
    [_failedRequestArray addObject:request];
    [self handleRequestDelegateCallBack];
}

- (void)handleRequestDelegateCallBack
{
    if (_finishedCount + _failedCount == _requestArray.count)
    {
        if ([_delegate respondsToSelector:@selector(batchContinueRequestFinished:failedRequest:)])
        {
            [_delegate batchContinueRequestFinished:self failedRequest:_failedRequestArray];
        }
        if (_completionBlock)
        {
            _completionBlock(self);
        }
        [self clearCompletionBlock];
        
        [[HYBatchContinueRequestAgent sharedAgent] removeBatchRequest:self];
    }
}

- (NSArray *)failedRequestArray
{
    return [_failedRequestArray copy];
}

@end
