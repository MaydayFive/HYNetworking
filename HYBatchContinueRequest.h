//
//  HYBatchContinueRequest.h
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/17.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HYRequest;
@class HYBatchContinueRequest;

@protocol HYBatchContinueRequestDelegate <NSObject>

@optional


- (void)batchContinueRequestFinished:(HYBatchContinueRequest *)batchRequest failedRequest:(NSArray<HYRequest *> *)failedRequestArray;

//once request falied
- (void)batchContinueRequestFailed:(HYBatchContinueRequest *)batchRequest failedRequest:(HYRequest *)request;

@end

//
@interface HYBatchContinueRequest : NSObject

@property (nonatomic, strong, readonly) NSArray<HYRequest *> *requestArray;

@property (nonatomic, weak, nullable) id<HYBatchContinueRequestDelegate> delegate;

@property (nonatomic, copy, nullable) void (^completionBlock)(HYBatchContinueRequest *);

///  Tag can be used to identify batch request. Default value is 0.
@property (nonatomic) NSInteger tag;

@property (nonatomic, strong, readonly) NSArray<HYRequest *> *failedRequestArray;

/**
 Creates a `HYBatchRequest` with a bunch of requests.
 
 @param requestArray requests useds to create batch request
 @return HYBatchRequest
 */
- (instancetype)initWithRequestArray:(NSArray<HYRequest *> *)requestArray;

- (void)setCompletionBlockWithCompletion:(nullable void (^)(HYBatchContinueRequest *batchRequest))completion;

///  Nil out both success and failure callback blocks.
- (void)clearCompletionBlock;

///  Append all the requests to queue.
- (void)start;

///  Stop all the requests of the batch request.
- (void)stop;

///  Convenience method to start the batch request with block callbacks.
- (void)startWithCompletionBlockWithCompletion:(nullable void (^)(HYBatchContinueRequest *batchRequest))completion;

- (BOOL)isDataFromCache;

@end

NS_ASSUME_NONNULL_END
