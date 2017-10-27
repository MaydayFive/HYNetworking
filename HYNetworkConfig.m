//
//  HYNetworkConfig.m
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/4.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import "HYNetworkConfig.h"
#import "HYBaseRequest.h"

#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif

@implementation HYNetworkConfig
{
    NSMutableArray<id<HYUrlFilterProtocol>> *_urlFilters;
    NSMutableArray<id<HYCacheDirPathFilterProtocol>> *_cacheDirPathFilters;
}

+ (HYNetworkConfig *)sharedConfig
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _baseUrl = @"";
        _cdnUrl = @"";
        _urlFilters = [NSMutableArray array];
        _cacheDirPathFilters = [NSMutableArray array];
        _securityPolicy = [AFSecurityPolicy defaultPolicy];
        _debugLogEnabled = NO;
    }
    return self;
}

- (void)addUrlFilter:(id<HYUrlFilterProtocol>)filter
{
    [_urlFilters addObject:filter];
}

- (void)clearUrlFilter {
    [_urlFilters removeAllObjects];
}

- (void)addCacheDirPathFilter:(id<HYCacheDirPathFilterProtocol>)filter
{
    [_cacheDirPathFilters addObject:filter];
}

- (void)clearCacheDirPathFilter {
    [_cacheDirPathFilters removeAllObjects];
}

- (NSArray<id<HYUrlFilterProtocol>> *)urlFilters
{
    return [_urlFilters copy];
}

- (NSArray<id<HYCacheDirPathFilterProtocol>> *)cacheDirPathFilters
{
    return [_cacheDirPathFilters copy];
}

#pragma mark - NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>{ baseURL: %@ } { cdnURL: %@ }", NSStringFromClass([self class]), self, self.baseUrl, self.cdnUrl];
}

@end
