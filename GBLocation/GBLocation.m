//
//  GBLocation.m
//  GBLocation
//
//  Created by Luka Mirosevic on 21/06/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import "GBLocation.h"

#define kDefaultDesiredAccuracy kCLLocationAccuracyKilometer

@interface GBLocation () <CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager         *locationManager;
@property (strong, nonatomic, readwrite) CLLocation     *myLocation;
@property (copy, nonatomic) DidFetchLocationBlock       didFetchLocationBlock;
@property (assign, nonatomic) CLLocationAccuracy        desiredAccuracy;

@end

@implementation GBLocation

#pragma mark - memory

+(GBLocation *)sharedLocation {
    static GBLocation *sharedLocation;
    
    @synchronized(self) {
        if (!sharedLocation) {
            sharedLocation = [GBLocation new];
        }
        
        return sharedLocation;
    }
}

- (id)init {
    self = [super init];
    if (self) {
        self.locationManager = [CLLocationManager new];
        self.locationManager.delegate = self;
        self.desiredAccuracy = kDefaultDesiredAccuracy;
    }
    
    return self;
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [manager stopUpdatingLocation];
    
    if (self.didFetchLocationBlock) {
        self.didFetchLocationBlock(NO, self.myLocation);
        self.didFetchLocationBlock = nil;
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    if (newLocation.horizontalAccuracy > 0 && newLocation.horizontalAccuracy <= self.desiredAccuracy) {
        //remember the location
        self.myLocation = newLocation;
        
        //turn off future updates
        [manager stopUpdatingLocation];
        
        if (self.didFetchLocationBlock) {
            self.didFetchLocationBlock(YES, self.myLocation);
            self.didFetchLocationBlock = nil;
        }
    }
}

#pragma mark - API

-(void)fetchCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy {
    self.desiredAccuracy = accuracy;
    
    [self _startUpdates];
}

-(void)refreshCurrentLocationWithCompletion:(DidFetchLocationBlock)block {
    [self refreshCurrentLocationWithAccuracy:self.desiredAccuracy completion:block];
}

-(void)refreshCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy completion:(DidFetchLocationBlock)block {
    self.didFetchLocationBlock = block;
    self.desiredAccuracy = accuracy;
    
    [self _startUpdates];
}

-(void)_startUpdates {
    self.locationManager.desiredAccuracy = self.desiredAccuracy;
    [self.locationManager startUpdatingLocation];
}

@end
