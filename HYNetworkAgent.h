//
//  HYNetworkAgent.h
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/9.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HYBaseRequest;

@interface HYNetworkAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (HYNetworkAgent *)sharedAgent;

- (void)addRequest:(HYBaseRequest *)request;

- (void)cancelRequest:(HYBaseRequest *)request;

- (void)cancelAllRequests;

/**
 返回请求的绝对路径

 @param request request The request to parse. Should not be nil.
 @return The result URL.
 */
- (NSString *)buildRequestUrl:(HYBaseRequest *)request;
@end

NS_ASSUME_NONNULL_END
