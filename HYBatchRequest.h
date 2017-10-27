//
//  HYBatchRequest.h
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/17.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HYRequest;
@class HYBatchRequest;

@protocol YTKBatchRequestDelegate <NSObject>

@optional

- (void)batchRequestFinished:(HYBatchRequest *)batchRequest;

- (void)batchRequestFailed:(HYBatchRequest *)batchRequest;

@end

//
@interface HYBatchRequest : NSObject

@property (nonatomic, strong, readonly) NSArray<HYRequest *> *requestArray;

@property (nonatomic, weak, nullable) id<YTKBatchRequestDelegate> delegate;

@property (nonatomic, copy, nullable) void (^successCompletionBlock)(HYBatchRequest *);

@property (nonatomic, copy, nullable) void (^failureCompletionBlock)(HYBatchRequest *);

///  Tag can be used to identify batch request. Default value is 0.
@property (nonatomic) NSInteger tag;

///  The first request that failed (and causing the batch request to fail).
@property (nonatomic, strong, readonly, nullable) HYRequest *failedRequest;

/**
 Creates a `HYBatchRequest` with a bunch of requests.

 @param requestArray requests useds to create batch request
 @return HYBatchRequest
 */
- (instancetype)initWithRequestArray:(NSArray<HYRequest *> *)requestArray;

- (void)setCompletionBlockWithSuccess:(nullable void (^)(HYBatchRequest *batchRequest))success
                              failure:(nullable void (^)(HYBatchRequest *batchRequest))failure;

///  Nil out both success and failure callback blocks.
- (void)clearCompletionBlock;

///  Append all the requests to queue.
- (void)start;

///  Stop all the requests of the batch request.
- (void)stop;

///  Convenience method to start the batch request with block callbacks.
- (void)startWithCompletionBlockWithSuccess:(nullable void (^)(HYBatchRequest *batchRequest))success
                                    failure:(nullable void (^)(HYBatchRequest *batchRequest))failure;

- (BOOL)isDataFromCache;

@end

NS_ASSUME_NONNULL_END
