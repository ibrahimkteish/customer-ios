//
//  KUSColor.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/17/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSColor.h"

@implementation KUSColor

+ (UIColor *)blueColor
{
    return [UIColor colorWithRed:66.0/255.0
                           green:130.0/255.0
                            blue:252.0/255.0
                           alpha:1.0];
}

+ (UIColor *)greenColor
{
    return [UIColor colorWithRed:109.0/255.0
                           green:183.0/255.0
                            blue:109.0/255.0
                           alpha:1.0];
}

+ (UIColor *)orangeColor
{
    return [UIColor colorWithRed:235.0/255.0
                           green:112.0/255.0
                            blue:95.0/255.0
                           alpha:1.0];
}

+ (UIColor *)yellowColor
{
    return [UIColor colorWithRed:245.0/255.0
                           green:209.0/255.0
                            blue:0.0/255.0
                           alpha:1.0];
}

+ (UIColor *)lightGrayColor
{
    return [UIColor colorWithWhite:237.0/255.0 alpha:1.0];
}

+ (UIColor *)grayColor
{
    return [UIColor colorWithRed:236.0/255.0
                           green:239.0/255.0
                            blue:241.0/255.0
                           alpha:1.0];
}

+ (UIColor *)darkGrayColor
{
    return [UIColor colorWithWhite:142.0/255.0 alpha:1.0];
}

@end