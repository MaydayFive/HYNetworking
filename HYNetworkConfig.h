//
//  HYNetworkConfig.h
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/4.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HYBaseRequest;
@class AFSecurityPolicy;

@protocol HYUrlFilterProtocol <NSObject>

- (NSString *)filterUrl:(NSString *)originUrl withRequest:(HYBaseRequest *)request;

@end


@protocol HYCacheDirPathFilterProtocol <NSObject>

- (NSString *)filterCacheDirPath:(NSString *)originPath withRequest:(HYBaseRequest *)request;

@end

@interface HYNetworkConfig : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

///  Return a shared config object.
+ (HYNetworkConfig *)sharedConfig;

@property (nonatomic, strong) NSString *baseUrl;

@property (nonatomic, strong) NSString *cdnUrl;

///  URL filters. See also `HYUrlFilterProtocol`.
@property (nonatomic, strong, readonly) NSArray<id<HYUrlFilterProtocol>> *urlFilters;

@property (nonatomic, strong, readonly) NSArray<id<HYCacheDirPathFilterProtocol>> *cacheDirPathFilters;

@property (nonatomic, strong) AFSecurityPolicy *securityPolicy;

@property (nonatomic) BOOL debugLogEnabled;

///  SessionConfiguration will be used to initialize AFHTTPSessionManager. Default is nil.
@property (nonatomic, strong) NSURLSessionConfiguration* sessionConfiguration;

///  Add a new URL filter.(增加参数限制 key:value)
- (void)addUrlFilter:(id<HYUrlFilterProtocol>)filter;
///  Remove all URL filters.
- (void)clearUrlFilter;
///  Add a new cache path filter
- (void)addCacheDirPathFilter:(id<HYCacheDirPathFilterProtocol>)filter;
///  Clear all cache path filters.
- (void)clearCacheDirPathFilter;

@end

NS_ASSUME_NONNULL_END
