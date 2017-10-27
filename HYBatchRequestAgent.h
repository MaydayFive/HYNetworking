//
//  HYBatchRequestAgent.h
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/17.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HYBatchRequest;

@interface HYBatchRequestAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

///  Get the shared batch request agent.
+ (HYBatchRequestAgent *)sharedAgent;

///  Add a batch request.
- (void)addBatchRequest:(HYBatchRequest *)request;

///  Remove a previously added batch request.
- (void)removeBatchRequest:(HYBatchRequest *)request;

@end

NS_ASSUME_NONNULL_END
