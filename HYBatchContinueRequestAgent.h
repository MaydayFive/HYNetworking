//
//  HYBatchContinueRequestAgent.h
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/17.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import <Foundation/Foundation.h>
@class HYBatchContinueRequest;

@interface HYBatchContinueRequestAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

///  Get the shared batch request agent.
+ (HYBatchContinueRequestAgent *)sharedAgent;

///  Add a batch request.
- (void)addBatchRequest:(HYBatchContinueRequest *)request;

///  Remove a previously added batch request.
- (void)removeBatchRequest:(HYBatchContinueRequest *)request;

@end
