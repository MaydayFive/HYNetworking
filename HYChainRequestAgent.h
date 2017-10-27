//
//  HYChainRequestAgent.h
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/16.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HYChainRequest;

@interface HYChainRequestAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

///  Get the shared chain request agent.
+ (HYChainRequestAgent *)sharedAgent;

///  Add a chain request.
- (void)addChainRequest:(HYChainRequest *)request;

///  Remove a previously added chain request.
- (void)removeChainRequest:(HYChainRequest *)request;

@end

NS_ASSUME_NONNULL_END
