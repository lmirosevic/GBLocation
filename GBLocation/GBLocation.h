//
//  GBLocation.h
//  GBLocation
//
//  Created by Luka Mirosevic on 21/06/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreLocation/CoreLocation.h>

//property to get the location

typedef void(^DidFetchLocationBlock)(BOOL success, CLLocation *myLocation);

@interface GBLocation : NSObject

@property (strong, nonatomic, readonly) CLLocation      *myLocation;

+(GBLocation *)sharedLocation;

-(void)fetchCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy;
-(void)refreshCurrentLocationWithCompletion:(DidFetchLocationBlock)block;
-(void)refreshCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy completion:(DidFetchLocationBlock)block;

@end
