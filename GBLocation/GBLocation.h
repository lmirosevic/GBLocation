//
//  GBLocation.h
//  GBLocation
//
//  Created by Luka Mirosevic on 21/06/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreLocation/CoreLocation.h>

extern NSTimeInterval const kGBLocationAlwaysFetchFreshLocation;

typedef enum {
    GBLocationFetchStateFailed,
    GBLocationFetchStateSuccess,
    GBLocationFetchStateCancelled,
} GBLocationFetchState;

typedef enum {
    GBLocationUsageAuthorizationAlways,
    GBLocationUsageAuthorizationWhenInUse,
} GBLocationUsageAuthorization;

typedef void(^DidFetchLocationBlock)(GBLocationFetchState state, CLLocation *myLocation);
typedef void(^UserDidFinishingAuthorizingLocationServicesBlock)(CLAuthorizationStatus authorizationStatus);

@protocol GBLocationDelegate;

@interface GBLocationFetch : NSObject

-(void)cancel;

@end

@interface GBLocation : NSObject

/**
 The latest, current location of the device.
 */
@property (strong, nonatomic, readonly) CLLocation              *myLocation;

/**
 Timeout after which to stop trying to fetch a new location. If the timeout is reached the library will return the most recent stored location, however it will continue fetching the location in the background so next time the location will be fresher.
 
 Units in seconds.
 
 Defaults to 4.
 */
@property (assign, nonatomic) NSTimeInterval                    timeout;

/**
 Sets how often the library should start up the location hardware in order to obtain a fresh location. If a location is requested and the actual location is younger than the refreshInterval, then that location is returned and the location hardware is not turned on--saving power.
 
 Units in seconds.
 
 Defaults to kGBLocationAlwaysFetchFreshLocation.
 */
@property (assign, nonatomic) NSTimeInterval                    refreshInterval;

/**
 Set this to YES if the library should automatically request a location authorization from the user, NO if you'd rather ask the user manually and receive a null location in the meantime.
 
 Defaults to YES.
 */
@property (assign, nonatomic) BOOL                              shouldAutomaticallyRequestLocationAuthorization;

/**
 Set what kind of authorization you would like from the user, foreground only or foreground+background. 
 
 WARNING: Make sure you set this property before requesting the location or triggering the location authorization.
 
 This is only relevant on iOS 8+.
 
 Defaults to GBLocationUsageAuthorizationAlways.
 */
@property (assign, nonatomic) GBLocationUsageAuthorization      locationAuthorizationType;

/**
 Returns YES if the location has previously been requested, either manually or automatically.
 */
@property (assign, nonatomic, readonly) BOOL                    hasRequestedLocationAuthorization;

/**
 The shared singleton.
 */
+(GBLocation *)sharedLocation;

/**
 Triggers a location update in the library.
 */
-(void)refreshCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy;

/**
 Updates the current device location and returns it (via block).
 */
-(GBLocationFetch *)refreshCurrentLocationWithCompletion:(DidFetchLocationBlock)block;

/**
 Updates the current device location and returns it (via block).
 */
-(GBLocationFetch *)refreshCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy completion:(DidFetchLocationBlock)block;

/**
 If you have set automaticallyRequestLocationAuthorization to NO, then you should call this before requesting any locations, to give the user the chance to authorize location information.
 
 Will throw an exception if called multiple times, use `hasRequestedLocationAuthorization` to check whether it has been requested already.
 */
-(void)triggerLocationAuthorizationRequestFromUserCompleted:(UserDidFinishingAuthorizingLocationServicesBlock)block;

@end
