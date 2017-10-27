//
//  HYNetworkAgent.m
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/9.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import "HYNetworkAgent.h"
#import "HYNetworkConfig.h"
#import "HYNetworkPrivate.h"
#import <pthread/pthread.h>

#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif

#define Lock() pthread_mutex_lock(&_lock)
#define Unlock() pthread_mutex_unlock(&_lock)

NSString *const kHYNetworkIncompleteDownloadFolderName = @"Incomplete";

@implementation HYNetworkAgent
{
    @private
    HYNetworkConfig *_config;
    AFHTTPSessionManager *_manager;
    AFJSONResponseSerializer *_jsonResponseSerializer;
    AFXMLParserResponseSerializer *_xmlParserResponseSerialzier;
    NSMutableDictionary<NSNumber *, HYBaseRequest *> *_requestsRecord;
    
    //The dispatch queue for `completionBlock`. If `NULL` (default), the main queue is used.
    dispatch_queue_t _processingQueue;
    pthread_mutex_t _lock;
    NSIndexSet *_allStatusCodes;
}

+ (HYNetworkAgent *)sharedAgent
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
        _config = [HYNetworkConfig sharedConfig];
        _manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:_config.sessionConfiguration];
        _manager.securityPolicy = _config.securityPolicy;
        _manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        _manager.responseSerializer.acceptableStatusCodes = _allStatusCodes;
        
        _processingQueue = dispatch_queue_create("com.hycmcc.networkagent.processing", DISPATCH_QUEUE_CONCURRENT);
        _manager.completionQueue = _processingQueue;
        _requestsRecord = [NSMutableDictionary dictionary];
        _allStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(100, 500)];

        pthread_mutex_init(&_lock, NULL);
    }
    return self;
}

- (void)addRequest:(HYBaseRequest *)request
{
    NSParameterAssert(request != nil);
    NSError * __autoreleasing requestSerializationError = nil;
    
    NSURLRequest *customUrlRequest = [request buildCustomUrlRequest];
    if (customUrlRequest)
    {
        __block NSURLSessionDataTask *dataTask = nil;
        dataTask = [_manager dataTaskWithRequest:customUrlRequest completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
            
        }];
        request.requestTask = dataTask;
    }
    else
    {
        request.requestTask = [self sessionTaskForRequest:request error:&requestSerializationError];
    }
    
    if (requestSerializationError)
    {
        [self requestDidFailWithRequest:request error:requestSerializationError];
    }
    
    NSAssert(request.requestTask != nil, @"requestTask should not be nil");
    
    if ([request.requestTask respondsToSelector:@selector(priority)])
    {
        switch (request.requestPriority)
        {
            case HYRequestPriorityHigh:
                request.requestTask.priority = NSURLSessionTaskPriorityHigh;
                break;
            case HYRequestPriorityLow:
                request.requestTask.priority = NSURLSessionTaskPriorityLow;
                break;
            case HYRequestPriorityDefault:
                /*!!fall through*/
            default:
                request.requestTask.priority = NSURLSessionTaskPriorityDefault;
                break;
        }
    }
    
    //重定向
    if (request.taskWillPerformHTTPRedirection)
    {
        [_manager setTaskWillPerformHTTPRedirectionBlock:request.taskWillPerformHTTPRedirection];
    }
    
    [self addRequestToRecord:request];
    [request.requestTask resume];
}

- (void)cancelRequest:(HYBaseRequest *)request
{
    NSParameterAssert(request != nil);
    
//在 YTKNetworkAgent 类中的 -cancelRequest 方法中，[request.requestTask cancel] 并没有判断 task 是否是 NSURLSessionDownloadTask类。导致取消下载时 -requestDidFailWithRequest:error: 获取不到断点描述数据 NSURLSessionDownloadTaskResumeData。
//希望在取消请求时加上判断，如果是 NSURLSessionDownloadTask 调用-cancelByProducingResumeData: ，其他情况才调用 -cancel。
    
    if (request.resumableDownloadPath)
    {
        NSURLSessionDownloadTask *requestTask = (NSURLSessionDownloadTask *)request.requestTask;
        [requestTask cancelByProducingResumeData:^(NSData *resumeData) {
            NSURL *localUrl = [self incompleteDownloadTempPathForDownloadPath:request.resumableDownloadPath];
            [resumeData writeToFile:localUrl.path atomically:YES];
            }];
    }
    else
    {
        [request.requestTask cancel];
    }
//    [request.requestTask cancel];
    [self removeRequestFromRecord:request];
    [request clearCompletionBlock];
}

- (void)cancelAllRequests
{
    Lock();
    NSArray *allKeys = [_requestsRecord allKeys];
    Unlock();
    if (allKeys && allKeys.count > 0)
    {
        NSArray *copiedKeys = [allKeys copy];
        for (NSNumber *key in copiedKeys)
        {
            Lock();
            HYBaseRequest *request = _requestsRecord[key];
            Unlock();
            // We are using non-recursive lock.
            // Do not lock `stop`, otherwise deadlock may occur.
            [request stop];
        }
    }
}


- (NSURLSessionTask *)sessionTaskForRequest:(HYBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error
{
    HYRequestMethod method = [request requestMethod];
    NSString *url = [self buildRequestUrl:request];
    id param = request.requestArgument;
    AFConstructingBlock constructingBlock = [request constructingBodyBlock];
    
    //二进制请求
    AFHTTPRequestSerializer *requestSerializer = [self requestSerializerForRequest:request];
    
    switch (method)
    {
        case HYRequestMethodGET:
        {
            if (request.resumableDownloadPath)
            {
                return [self downloadTaskWithDownloadPath:request.resumableDownloadPath requestSerializer:requestSerializer URLString:url parameters:param progress:request.resumableDownloadProgressBlock error:error];
            }
            else
            {
                return [self dataTaskWithHTTPMethod:@"GET" requestSerializer:requestSerializer URLString:url parameters:param error:error];
            }
        }
            break;
        case HYRequestMethodPOST:
        {
            return [self dataTaskWithHTTPMethod:@"POST" requestSerializer:requestSerializer URLString:url parameters:param constructingBodyWithBlock:constructingBlock progress:request.uploadProgressBlock error:error];
        }
            break;
        case HYRequestMethodHEAD:
        {
            return [self dataTaskWithHTTPMethod:@"HEAD" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        }
            break;
        case HYRequestMethodPUT:
        {
            return [self dataTaskWithHTTPMethod:@"PUT" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        }
            break;
        case HYRequestMethodDELETE:
        {
            return [self dataTaskWithHTTPMethod:@"DELETE" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        }
            break;
        case HYRequestMethodPATCH:
        {
            return [self dataTaskWithHTTPMethod:@"PATCH" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        }
            break;
        default:
            break;
    }
}

- (void)handleRequestResult:(NSURLSessionTask *)task responseObject:(id)responseObject error:(NSError *)error
{
    Lock();
    HYBaseRequest *request = _requestsRecord[@(task.taskIdentifier)];
    Unlock();
    
    if (!request)
    {
        return;
    }
    
    NSError * __autoreleasing serializationError = nil;
    NSError * __autoreleasing validationError = nil;
    
    NSError *requestError = nil;
    BOOL succeed = NO;
    
    
    request.responseObject = responseObject;
    if ([request.responseObject isKindOfClass:[NSData class]])
    {
        request.responseData = responseObject;
        request.responseString = [[NSString alloc] initWithData:responseObject encoding:[HYNetworkUtils stringEncodingWithRequest:request]];
    
        switch (request.responseSerializerType)
        {
            case HYResponseSerializerTypeHTTP:
                // Default serializer. Do nothing.
                break;
            case HYResponseSerializerTypeJSON:
                request.responseObject = [self.jsonResponseSerializer responseObjectForResponse:task.response data:request.responseData error:&serializationError];
                request.responseJSONObject = request.responseObject;
                break;
            case HYResponseSerializerTypeXMLParser:
                request.responseObject = [self.xmlParserResponseSerialzier responseObjectForResponse:task.response data:request.responseData error:&serializationError];
                break;
        }
    }
    
    if (error)
    {
        succeed = NO;
        requestError = error;
    }
    else if (serializationError)
    {
        succeed = NO;
        requestError = serializationError;
    }
    else
    {
        succeed = [self validateResult:request error:&validationError];
        requestError = validationError;
    }
    
    if (succeed)
    {
        [self requestDidSucceedWithRequest:request];
    }
    else
    {
        [self requestDidFailWithRequest:request error:requestError];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self removeRequestFromRecord:request];
        [request clearCompletionBlock];
    });
    
}

- (BOOL)validateResult:(HYBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error
{
    BOOL result = [request statusCodeValidator];
    if (!result)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:HYRequestValidationErrorDomain code:HYRequestValidationErrorInvalidStatusCode userInfo:@{NSLocalizedDescriptionKey:@"Invalid status code"}];
        }
        return result;
    }
    
    id json = [request responseJSONObject];
    id validator = [request jsonValidator];
    if (json && validator)
    {
        if (json && validator)
        {
            result = [HYNetworkUtils validateJSON:json withValidator:validator];
            if (!result)
            {
                if (error)
                {
                    *error = [NSError errorWithDomain:HYRequestValidationErrorDomain code:HYRequestValidationErrorInvalidJSONFormat userInfo:@{NSLocalizedDescriptionKey:@"Invalid JSON format"}];
                }
                return result;
            }
        }
    }
    return YES;
}

- (void)requestDidSucceedWithRequest:(HYBaseRequest *)request
{
    @autoreleasepool {
        [request requestCompletePreprocessor];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [request requestCompleteFilter];
        
        if (nil != request.delegate)
        {
            [request.delegate requestFinished:request];
        }
        if (request.successCompletionBlock)
        {
            request.successCompletionBlock(request);
        }
    });
}

- (void)requestDidFailWithRequest:(HYBaseRequest *)request error:(NSError *)error
{
    request.error = error;
    NSData *incompleteDownloadData = error.userInfo[NSURLSessionDownloadTaskResumeData];
    if (incompleteDownloadData)
    {
        [incompleteDownloadData writeToURL:[self incompleteDownloadTempPathForDownloadPath:request.resumableDownloadPath] atomically:YES];
    }
    
    if ([request.responseObject isKindOfClass:[NSURL class]])
    {
        //request.responseObject就是filePath
        NSURL *url = request.responseObject;
        if (url.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:url.path])
        {
            request.responseData = [NSData dataWithContentsOfURL:url];
            request.responseString = [[NSString alloc] initWithData:request.responseData encoding:[HYNetworkUtils stringEncodingWithRequest:request]];
            
            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        }
    }
    
    @autoreleasepool {
        [request requestFailedPreprocessor];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [request requestFailedFilter];
        
        if (nil != request.delegate)
        {
            [request.delegate requestFailed:request];
        }
        if (request.failureCompletionBlock) {
            request.failureCompletionBlock(request);
        }
    });
}

- (void)addRequestToRecord:(HYBaseRequest *)request
{
    Lock();
    _requestsRecord[@(request.requestTask.taskIdentifier)] = request;
    Unlock();
}

- (void)removeRequestFromRecord:(HYBaseRequest *)request
{
    Lock();
    [_requestsRecord removeObjectForKey:@(request.requestTask.taskIdentifier)];
    Unlock();
}

- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                               requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                                           error:(NSError * _Nullable __autoreleasing *)error
{
    return [self dataTaskWithHTTPMethod:method requestSerializer:requestSerializer URLString:URLString parameters:parameters constructingBodyWithBlock:nil progress:nil error:error];
}


- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                               requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                       constructingBodyWithBlock:(nullable void (^)(id <AFMultipartFormData> formData))block
                                        progress:(nullable void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                           error:(NSError * _Nullable __autoreleasing *)error
{
    NSMutableURLRequest *request = nil;
    if (block)
    {
        request = [requestSerializer multipartFormRequestWithMethod:method URLString:URLString parameters:parameters constructingBodyWithBlock:block error:error];
    }
    else
    {
        request = [requestSerializer requestWithMethod:method URLString:URLString parameters:parameters error:error];
    }
    
    __block NSURLSessionDataTask *dataTask = nil;
    
    if (uploadProgressBlock)
    {
        dataTask = [_manager dataTaskWithRequest:request uploadProgress:uploadProgressBlock downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        }];
    }
    else
    {
        dataTask = [_manager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
            
        }];
    }
    return dataTask;
}

- (NSURLSessionDownloadTask *)downloadTaskWithDownloadPath:(NSString *)downloadPath
                                         requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                                 URLString:(NSString *)URLString
                                                parameters:(id)parameters
                                                  progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                                     error:(NSError * _Nullable __autoreleasing *)error
{
    // add parameters to URL;
    NSMutableURLRequest *urlRequest = [requestSerializer requestWithMethod:@"GET" URLString:URLString parameters:parameters error:error];
    NSString *downloadTargetPath = nil;
    
    BOOL isDirectory;
    if (![[NSFileManager defaultManager] fileExistsAtPath:downloadPath isDirectory:&isDirectory])
    {
        isDirectory = NO;
    }
    
    if (isDirectory)
    {
        NSString *fileName = [urlRequest.URL lastPathComponent];
        downloadTargetPath = [NSString pathWithComponents:@[downloadPath, fileName]];
    }
    else
    {
        downloadTargetPath = downloadPath;
    }
    
    // AFN use `moveItemAtURL` to move downloaded file to target path,
    // this method aborts the move attempt if a file already exist at the path.
    // So we remove the exist file before we start the download task.
    if ([[NSFileManager defaultManager] fileExistsAtPath:downloadTargetPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:downloadTargetPath error:nil];
    }
    
    BOOL resumeDataFileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self incompleteDownloadTempPathForDownloadPath:downloadPath].path];
    
    NSData *data = [NSData dataWithContentsOfURL:[self incompleteDownloadTempPathForDownloadPath:downloadPath]];
    BOOL resumeDataIsValid = [HYNetworkUtils validateResumeData:data];
    
    BOOL canBeResumed = resumeDataFileExists && resumeDataIsValid;
    BOOL resumeSucceeded = NO;
    
    __block NSURLSessionDownloadTask *downloadTask = nil;
    
    // Try to resume with resumeData.
    // Even though we try to validate the resumeData, this may still fail and raise excecption.
    if (canBeResumed)
    {
        @try {
            downloadTask = [_manager downloadTaskWithResumeData:data progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                
                return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
                
            } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                [self handleRequestResult:downloadTask responseObject:filePath error:error];
            }];
            
            resumeSucceeded = YES;
            
        } @catch (NSException *exception) {
            resumeSucceeded = NO;
        }
    }
    
    if (!resumeSucceeded) {
        downloadTask = [_manager downloadTaskWithRequest:urlRequest progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
        } completionHandler:
                        ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                            [self handleRequestResult:downloadTask responseObject:filePath error:error];
                        }];
    }
    return downloadTask;
    
}

- (AFHTTPRequestSerializer *)requestSerializerForRequest:(HYBaseRequest *)request
{
    AFHTTPRequestSerializer *requestSerializer = nil;
    if (request.requestSerializerType == HYRequestSerializerTypeHTTP)
    {
        requestSerializer = [AFHTTPRequestSerializer serializer];
    }
    else if (request.requestSerializerType == HYRequestSerializerTypeJSON)
    {
        requestSerializer = [AFJSONRequestSerializer serializer];
    }
    
    requestSerializer.timeoutInterval = [request requestTimeoutInterval];
    //是否允许蜂窝网络
    requestSerializer.allowsCellularAccess = [request allowsCellularAccess];
    
    // If api needs server username and password
    NSArray<NSString *> *authorizationHeaderFieldArray = [request requestAuthorizationHeaderFieldArray];
    if (authorizationHeaderFieldArray != nil)
    {
        [requestSerializer setAuthorizationHeaderFieldWithUsername:authorizationHeaderFieldArray.firstObject password:authorizationHeaderFieldArray.lastObject];
    }
    
    // If api needs to add custom value to HTTPHeaderField
    NSDictionary<NSString *, NSString *> *headerFieldValueDictionary = [request requestHeaderFieldValueDictionary];
    if (headerFieldValueDictionary != nil)
    {
        for (NSString *httpHeaderField in headerFieldValueDictionary.allKeys)
        {
            NSString *value = headerFieldValueDictionary[httpHeaderField];
            [requestSerializer setValue:value forHTTPHeaderField:httpHeaderField];
        }
    }
    return requestSerializer;
}

- (AFJSONResponseSerializer *)jsonResponseSerializer
{
    if (!_jsonResponseSerializer)
    {
        _jsonResponseSerializer = [AFJSONResponseSerializer serializer];
        _jsonResponseSerializer.acceptableStatusCodes = _allStatusCodes;
        
    }
    return _jsonResponseSerializer;
}

- (AFXMLParserResponseSerializer *)xmlParserResponseSerialzier
{
    if (!_xmlParserResponseSerialzier)
    {
        _xmlParserResponseSerialzier = [AFXMLParserResponseSerializer serializer];
        _xmlParserResponseSerialzier.acceptableStatusCodes = _allStatusCodes;
    }
    return _xmlParserResponseSerialzier;
}

- (NSString *)buildRequestUrl:(HYBaseRequest *)request
{
    NSParameterAssert(request != nil);
    
    NSString *detailUrl = [request requestUrl];
    NSURL *temp = [NSURL URLWithString:detailUrl];
    // If detailUrl is valid URL
    if (temp && temp.host && temp.scheme)
    {
        return detailUrl;
    }
    // Filter URL if needed
    NSArray *filters = [_config urlFilters];
    for (id<HYUrlFilterProtocol> f in filters)
    {
        detailUrl = [f filterUrl:detailUrl withRequest:request];
    }
    
    NSString *baseUrl;
    if ([request useCDN])
    {
        if ([request cdnUrl].length > 0)
        {
            baseUrl = [request cdnUrl];
        }
        else
        {
            baseUrl = [_config cdnUrl];
        }
    }
    else
    {
        if ([request baseUrl].length > 0)
        {
            baseUrl = [request baseUrl];
        }
        else
        {
            baseUrl = [_config baseUrl];
        }
    }
    // URL slash compability
    NSURL *url = [NSURL URLWithString:baseUrl];
    
    if (baseUrl.length > 0 && ![baseUrl hasSuffix:@"/"])
    {
        url = [url URLByAppendingPathComponent:@""];
    }
    
    return [NSURL URLWithString:detailUrl relativeToURL:url].absoluteString;
}

#pragma mark - Resumable Download

- (NSString *)incompleteDownloadTempCacheFolder
{
    NSFileManager *fileManager = [NSFileManager new];
    static NSString *cacheFolder;
    
    if (!cacheFolder)
    {
        NSString *cacheDir = NSTemporaryDirectory();
        cacheFolder = [cacheDir stringByAppendingPathComponent:kHYNetworkIncompleteDownloadFolderName];
    }
    
    NSError *error = nil;
    if(![fileManager createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error])
    {
        cacheFolder = nil;
    }
    return cacheFolder;
}

- (NSURL *)incompleteDownloadTempPathForDownloadPath:(NSString *)downloadPath
{
    NSString *tempPath = nil;
    NSString *md5URLString = [HYNetworkUtils md5StringFromString:downloadPath];
    tempPath = [[self incompleteDownloadTempCacheFolder] stringByAppendingPathComponent:md5URLString];
    return [NSURL fileURLWithPath:tempPath];
}

@end
