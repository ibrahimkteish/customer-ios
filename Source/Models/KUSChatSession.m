//
//  KUSChatSession.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/4/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSChatSession.h"

@implementation KUSChatSession

#pragma mark - Class methods

+ (NSString *)modelType
{
    return @"chat_session";
}

#pragma mark - Lifecycle methods

- (instancetype)initWithJSON:(NSDictionary *)json
{
    self = [super initWithJSON:json];
    if (self) {
        _preview = [json valueForKeyPath:@"attributes.preview"];
        _trackingId = [json valueForKeyPath:@"attributes.trackingId"];
    }
    return self;
}

@end