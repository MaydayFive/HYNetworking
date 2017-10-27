//
//  HYChainRequest.h
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/16.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HYChainRequest;
@class HYBaseRequest;

@protocol HYChainRequestDelegate <NSObject>

@optional

/**
 Tell the delegate that the chain request has finished successfully.

 @param chainRequest The corresponding chain request.
 */
- (void)chainRequestFinished:(HYChainRequest *)chainRequest;

/**
 Tell the delegate that the chain request has failed.

 @param chainRequest The corresponding chain request.
 @param request      First failed request that causes the whole request to fail.
 */
- (void)chainRequestFailed:(HYChainRequest *)chainRequest failedBaseRequest:(HYBaseRequest *)request;

@end

typedef void (^HYChainCallback)(HYChainRequest *chainRequest, HYBaseRequest *baseRequest);

@interface HYChainRequest : NSObject

///  All the requests are stored in this array.
- (NSArray<HYBaseRequest *> *)requestArray;

@property (nonatomic, weak, nullable) id<HYChainRequestDelegate> delegate;

///  Start the chain request, adding first request in the chain to request queue.
- (void)start;

///  Stop the chain request. Remaining request in chain will be cancelled.
- (void)stop;


/**
 Add request to request chain

 @param request  The request to be chained.
 @param callback The finish callback
 */
- (void)addRequest:(HYBaseRequest *)request callback:(nullable HYChainCallback)callback;

@end

NS_ASSUME_NONNULL_END
