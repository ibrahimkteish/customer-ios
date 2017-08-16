//
//  KUSRequestManager.m
//  Kustomer
//
//  Created by Daniel Amitay on 8/13/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSRequestManager.h"

#import "KUSUserSession.h"

NSString *const kKustomerTrackingTokenHeaderKey = @"x-kustomer-tracking-token";

typedef void (^KUSTrackingTokenCompletion)(NSError *error, NSString *trackingToken);

@interface KUSRequestManager () <KUSObjectDataSourceListener> {
    __weak KUSUserSession *_userSession;
}

@property (nonatomic, strong, readonly) NSString *baseUrlString;
@property (nonatomic, strong, readonly) NSURLSession *urlSession;
@property (nonatomic, strong, readonly) dispatch_queue_t queue;

@property (nonatomic, copy, null_resettable) NSMutableArray<KUSTrackingTokenCompletion> *pendingTrackingTokenCompletions;

@end

@implementation KUSRequestManager

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super init];
    if (self) {
        _userSession = userSession;

        _baseUrlString = KUSBaseUrlStringFromOrgName(_userSession.orgName);

        _queue = dispatch_queue_create("com.kustomer.request-manager", nil);

        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
        operationQueue.underlyingQueue = _queue;
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        [configuration setTimeoutIntervalForRequest:15.0];
        _urlSession = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:operationQueue];

        [_userSession.trackingTokenDataSource addListener:self];
    }
    return self;
}

#pragma mark - URL methods

- (NSURL *)URLForEndpoint:(NSString *)endpoint
{
    NSString *endpointUrlString = [NSString stringWithFormat:@"%@%@", self.baseUrlString, endpoint];
    return [NSURL URLWithString:endpointUrlString];
}

#pragma mark - Request methods

- (void)getEndpoint:(NSString *)endpoint
      authenticated:(BOOL)authenticated
         completion:(KUSRequestCompletion)completion
{
    [self performRequestType:KUSRequestTypeGet
                    endpoint:endpoint
                      params:nil
               authenticated:authenticated
                  completion:completion];
}

- (void)performRequestType:(KUSRequestType)type
                  endpoint:(NSString *)endpoint
                    params:(NSDictionary<NSString *, id> *)params
             authenticated:(BOOL)authenticated
                completion:(KUSRequestCompletion)completion
{
    [self performRequestType:type
                         URL:[self URLForEndpoint:endpoint]
                      params:params
               authenticated:authenticated
                  completion:completion];
}

- (void)performRequestType:(KUSRequestType)type
                       URL:(NSURL *)URL
                    params:(NSDictionary<NSString *, id> *)params
             authenticated:(BOOL)authenticated
                completion:(KUSRequestCompletion)completion
{
    [self performRequestType:type
                         URL:URL
                      params:params
               authenticated:authenticated
           additionalHeaders:nil
                  completion:completion];
}

- (void)performRequestType:(KUSRequestType)type
                       URL:(NSURL *)URL
                    params:(NSDictionary<NSString *, id> *)params
             authenticated:(BOOL)authenticated
         additionalHeaders:(NSDictionary *)additionalHeaders
                completion:(KUSRequestCompletion)completion
{
    void (^safeComplete)(NSError *, NSDictionary *) = ^void(NSError *error, NSDictionary *response) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    completion(error, nil);
                } else {
                    completion(nil, response);
                }
            });
        }
    };

    void (^performRequestWithTrackingToken)(NSString *) = ^void(NSString *trackingToken) {
        NSURL *finalURL = (type == KUSRequestTypeGet ? KUSURLFromURLAndQueryParams(URL, params) : URL);
        NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:finalURL];
        [urlRequest setHTTPMethod:KUSRequestTypeToString(type)];
        [urlRequest setValue:@"kustomer" forHTTPHeaderField:@"X-Kustomer"];
        if (type != KUSRequestTypeGet) {
            KUSAttachJSONBodyToRequest(urlRequest, params);
        }

        if (authenticated && trackingToken) {
            [urlRequest setValue:trackingToken forHTTPHeaderField:kKustomerTrackingTokenHeaderKey];
        }

        void (^responseBlock)(NSData *, NSURLResponse *, NSError *) = ^void(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                safeComplete(error, nil);
                return;
            }
            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
            safeComplete(jsonError, json);
        };
        NSURLSessionDataTask *dataTask = [_urlSession dataTaskWithRequest:urlRequest completionHandler:responseBlock];
        [dataTask resume];
    };

    if (authenticated) {
        [self _dispenseTrackingToken:^(NSError *error, NSString *trackingToken) {
            if (error) {
                safeComplete(error, nil);
            } else {
                performRequestWithTrackingToken(trackingToken);
            }
        }];
    } else {
        dispatch_async(self.queue, ^{
            performRequestWithTrackingToken(nil);
        });
    }
}

#pragma mark - Internal methods

- (void)_dispenseTrackingToken:(KUSTrackingTokenCompletion)callback
{
    NSString *trackingToken = _userSession.trackingTokenDataSource.currentTrackingToken;
    if (trackingToken) {
        dispatch_async(self.queue, ^{
            callback(nil, trackingToken);
        });
    } else {
        [self.pendingTrackingTokenCompletions addObject:callback];
        [_userSession.trackingTokenDataSource fetch];
    }
}

- (void)_firePendingTokenCompletionsWithToken:(NSString *)token error:(NSError *)error
{
    NSArray<KUSTrackingTokenCompletion> *completions = [_pendingTrackingTokenCompletions copy];
    _pendingTrackingTokenCompletions = nil;

    if (completions.count) {
        dispatch_async(self.queue, ^{
            for (KUSTrackingTokenCompletion completion in completions) {
                completion(error, token);
            }
        });
    }
}

#pragma mark - KUSObjectDataSourceListener methods

- (void)objectDataSourceDidLoad:(KUSObjectDataSource *)dataSource
{
    if (dataSource == _userSession.trackingTokenDataSource) {
        NSString *trackingToken = _userSession.trackingTokenDataSource.currentTrackingToken;
        [self _firePendingTokenCompletionsWithToken:trackingToken error:nil];
    }
}

- (void)objectDataSource:(KUSObjectDataSource *)dataSource didReceiveError:(NSError *)error
{
    [self _firePendingTokenCompletionsWithToken:nil error:error];
}

#pragma mark - Lazy-loaded methods

- (NSMutableArray<KUSTrackingTokenCompletion> *)pendingTrackingTokenCompletions
{
    if (_pendingTrackingTokenCompletions == nil) {
        _pendingTrackingTokenCompletions = [[NSMutableArray alloc] init];
    }
    return _pendingTrackingTokenCompletions;
}

#pragma mark - Helper methods

static NSString *KUSRequestTypeToString(KUSRequestType type)
{
    switch (type) {
        case KUSRequestTypeGet:
            return @"GET";
        case KUSRequestTypePost:
            return @"POST";
        case KUSRequestTypePatch:
            return @"PATCH";
        case KUSRequestTypePut:
            return @"PUT";
        case KUSRequestTypeDelete:
            return @"DELETE";
    }
}

static NSString *KUSBaseUrlStringFromOrgName(NSString *orgName)
{
    NSDictionary<NSString *, NSString *> *environment = [[NSProcessInfo processInfo] environment];
    NSString *baseDomain = environment[@"KUSTOMER_BASE_DOMAIN"] ?: @"kustomerapp.com";
    return [NSString stringWithFormat:@"https://%@.api.%@", orgName, baseDomain];
}

static NSURL *KUSURLFromURLAndQueryParams(NSURL *URL, NSDictionary<NSString *, id> *params)
{
    if (params.count < 1) {
        return URL;
    }

    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSMutableArray<NSURLQueryItem *> *queryItems = [[NSMutableArray alloc] initWithCapacity:params.count];
    for (NSString *key in params) {
        id value = params[key];
        NSString *valueString = nil;
        if ([value isKindOfClass:[NSString class]]) {
            valueString = (NSString *)value;
        } else {
            valueString = [NSString stringWithFormat:@"%@", value];
        }
        NSURLQueryItem *queryItem = [NSURLQueryItem queryItemWithName:key value:valueString];
        [queryItems addObject:queryItem];
    }
    urlComponents.queryItems = queryItems;
    return urlComponents.URL;
}

static void KUSAttachJSONBodyToRequest(NSMutableURLRequest *mutableURLRequest, NSDictionary<NSString *, id> *params)
{
    if (params.count > 0) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:kNilOptions error:NULL];
        [mutableURLRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSString *contentLength = [NSString stringWithFormat:@"%lu", (unsigned long)jsonData.length];
        [mutableURLRequest setValue:contentLength forHTTPHeaderField:@"Content-Length"];
        [mutableURLRequest setHTTPBody:jsonData];
    }
}

@end