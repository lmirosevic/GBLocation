//
//  GBLocation.m
//  GBLocation
//
//  Created by Luka Mirosevic on 21/06/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import "GBLocation.h"

static NSTimeInterval const kDefaultTimeout =           4;
#define kDefaultDesiredAccuracy                         kCLLocationAccuracyKilometer

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
        if ([self.locationManager respondsToSelector:@selector(setPausesLocationUpdatesAutomatically:)]) [self.locationManager setPausesLocationUpdatesAutomatically:NO];//ios 6 only
        
        self.desiredAccuracy = kDefaultDesiredAccuracy;
        self.timeout = kDefaultTimeout;
    }
    
    return self;
}

#pragma mark - CLLocationManagerDelegate

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [manager stopUpdatingLocation];
    
    [self _processBlocksWithSuccess:NO];
}

//called in iOS 5
-(void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    [self _gotNewLocation:newLocation];
}

//called in iOS 6+
-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    [self _gotNewLocation:[locations lastObject]];
}

#pragma mark - API

-(void)refreshCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy {
    [self refreshCurrentLocationWithAccuracy:accuracy completion:nil];
}

-(void)refreshCurrentLocationWithCompletion:(DidFetchLocationBlock)block {
    [self refreshCurrentLocationWithAccuracy:self.desiredAccuracy completion:block];
}

-(void)refreshCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy completion:(DidFetchLocationBlock)block {
    [self _addBlock:block];
    self.desiredAccuracy = MIN(self.desiredAccuracy, accuracy);
    
    [self _startUpdates];
    
    if (block) {
        //after a timeout...
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^{
            //call the block with a fail
            block(NO, self.myLocation);
            
            //remove it from the array
            [self _removeBlock:block];
        });
    }
}

#pragma mark - util

-(void)_gotNewLocation:(CLLocation *)location {
    if (location.horizontalAccuracy > 0 && location.horizontalAccuracy <= self.desiredAccuracy) {
        //remember the location
        self.myLocation = location;
        
        [self _processBlocksWithSuccess:YES];
        
        [self _stopUpdates];
    }
}

-(void)_startUpdates {
    [self.locationManager stopUpdatingLocation];//calling this triggers an initial fix to be sent again
    self.locationManager.desiredAccuracy = self.desiredAccuracy;
    [self.locationManager startUpdatingLocation];
}

-(void)_stopUpdates {
    [self.locationManager stopUpdatingLocation];
}

-(void)_processBlocksWithSuccess:(BOOL)success {
    //go through all the blocks, call them
    for (DidFetchLocationBlock block in self.didFetchLocationBlockHandlers) {
        block(success, self.myLocation);
    }
    
    //reset the array (it's lazy)
    self.didFetchLocationBlockHandlers = nil;
}

-(void)_addBlock:(DidFetchLocationBlock)block {
    if (block) {
        //add a copy to our array
        [self.didFetchLocationBlockHandlers addObject:[block copy]];
    }
}

-(void)_removeBlock:(DidFetchLocationBlock)block {
    if (block) {
        //add a copy to our array
        [self.didFetchLocationBlockHandlers removeObject:block];
    }
}

@end
