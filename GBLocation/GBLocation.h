//
//  GBLocation.h
//  GBLocation
//
//  Created by Luka Mirosevic on 21/06/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreLocation/CoreLocation.h>

typedef void(^DidFetchLocationBlock)(BOOL success, CLLocation *myLocation);

@interface GBLocation : NSObject

@property (strong, nonatomic, readonly) CLLocation      *myLocation;
@property (assign, nonatomic) NSTimeInterval            timeout;//defaults to 4 seconds

+(GBLocation *)sharedLocation;

-(void)refreshCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy;
-(void)refreshCurrentLocationWithCompletion:(DidFetchLocationBlock)block;
-(void)refreshCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy completion:(DidFetchLocationBlock)block;

@end
