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
@property (strong, nonatomic) NSMutableArray            *didFetchLocationBlockHandlers;
@property (assign, nonatomic) CLLocationAccuracy        desiredAccuracy;

@end

@implementation GBLocation

#pragma mark - CA

-(NSMutableArray *)didFetchLocationBlockHandlers {
    if (!_didFetchLocationBlockHandlers) {
        _didFetchLocationBlockHandlers = [NSMutableArray new];
    }
    
    return _didFetchLocationBlockHandlers;
}

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

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"failed with error");
    [manager stopUpdatingLocation];
    
    [self _processBlocksWithSuccess:NO myLocation:self.myLocation];
}

-(void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    if (newLocation.horizontalAccuracy > 0 && newLocation.horizontalAccuracy <= self.desiredAccuracy) {
        NSLog(@"got one: %f", newLocation.horizontalAccuracy);
        //remember the location
        self.myLocation = newLocation;
        
        [self _processBlocksWithSuccess:YES myLocation:self.myLocation];
        
        [self _stopUpdatesForManager:manager];
    }
    else {
        NSLog(@"not good enough: %f", newLocation.horizontalAccuracy);
    }
}

#pragma mark - API

-(void)fetchCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy {
    NSLog(@"fetch %f", accuracy);
    self.desiredAccuracy = accuracy;
    
    [self _startUpdates];
}

-(void)refreshCurrentLocationWithCompletion:(DidFetchLocationBlock)block {
    NSLog(@"refresh %f", self.desiredAccuracy);
    [self refreshCurrentLocationWithAccuracy:self.desiredAccuracy completion:block];
}

-(void)refreshCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy completion:(DidFetchLocationBlock)block {
    NSLog(@"refresh with competion %f", accuracy);
    [self _addBlock:block];
    self.desiredAccuracy = MIN(self.desiredAccuracy, accuracy);
    
    [self _startUpdates];
}

#pragma mark - util

-(void)_startUpdates {
    NSLog(@"start uodates");
    self.locationManager.desiredAccuracy = self.desiredAccuracy;
    [self.locationManager startUpdatingLocation];
}

-(void)_stopUpdatesForManager:(CLLocationManager *)manager {
    NSLog(@"stop updates");
    //turn off future updates
    [manager stopUpdatingLocation];
}

-(void)_processBlocksWithSuccess:(BOOL)success myLocation:(CLLocation *)myLocation {
    NSLog(@"process blcoks");
    //go through all the blocks, call them
    for (DidFetchLocationBlock block in self.didFetchLocationBlockHandlers) {
        NSLog(@"run block");
        block(success, myLocation);
    }
    
    NSLog(@"kill blocks");
    //reset the array (it's lazy)
    self.didFetchLocationBlockHandlers = nil;
}

-(void)_addBlock:(DidFetchLocationBlock)block {
    NSLog(@"add block");
    //add a copy to our array
    [self.didFetchLocationBlockHandlers addObject:[block copy]];
}

@end
