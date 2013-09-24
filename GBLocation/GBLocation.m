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

@interface GBLocationFetch ()

@property (weak, nonatomic) DidFetchLocationBlock       block;
@property (weak, nonatomic) GBLocation                  *GBLocation;

+(GBLocationFetch *)cancelWithGBLocation:(GBLocation *)GBLocation block:(DidFetchLocationBlock)block;
-(id)initWithGBLocation:(GBLocation *)GBLocation block:(DidFetchLocationBlock)block;

@end

@interface GBLocation () <CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager         *locationManager;
@property (strong, nonatomic, readwrite) CLLocation     *myLocation;
@property (strong, nonatomic) NSMutableArray            *didFetchLocationBlockHandlers;
@property (assign, nonatomic) CLLocationAccuracy        desiredAccuracy;
@property (assign, nonatomic) BOOL                      timeoutShunted;

-(void)_removeBlock:(DidFetchLocationBlock)block;

@end

@implementation GBLocationFetch

#pragma mark - Mem

+(GBLocationFetch *)cancelWithGBLocation:(GBLocation *)GBLocation block:(DidFetchLocationBlock)block {
    return [[self alloc] initWithGBLocation:GBLocation block:block];
}

-(id)initWithGBLocation:(GBLocation *)GBLocation block:(DidFetchLocationBlock)block {
    if (self = [super init]) {
        self.GBLocation = GBLocation;
        self.block = block;
    }
    
    return self;
}

#pragma mark - API

-(void)cancel {
    //return cancelled state and old location
    if (self.block) self.block(GBLocationFetchStateCancelled, self.GBLocation.myLocation);
    
    [self.GBLocation _removeBlock:self.block];
    self.block = nil;//just for good measure in case someone else is retaining the block
}

@end

@implementation GBLocation

#pragma mark - CA

-(NSMutableArray *)didFetchLocationBlockHandlers {
    if (!_didFetchLocationBlockHandlers) {
        _didFetchLocationBlockHandlers = [NSMutableArray new];
    }
    
    return _didFetchLocationBlockHandlers;
}

-(void)setMyLocation:(CLLocation *)myLocation {
    _myLocation = myLocation;
    
    //turn off the timeout shunt if we get a location
    if (myLocation) {
        self.timeoutShunted = NO;
    }
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
        self.timeoutShunted = YES;
    }
    
    return self;
}

#pragma mark - CLLocationManagerDelegate

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [manager stopUpdatingLocation];
    
    [self _processBlocksWithState:GBLocationFetchStateFailed];
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

-(GBLocationFetch *)refreshCurrentLocationWithCompletion:(DidFetchLocationBlock)block {
    return [self refreshCurrentLocationWithAccuracy:self.desiredAccuracy completion:block];
}

-(GBLocationFetch *)refreshCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy completion:(DidFetchLocationBlock)block {
    DidFetchLocationBlock copiedBlock = [block copy];
    [self _addBlock:copiedBlock];
    
    self.desiredAccuracy = MIN(self.desiredAccuracy, accuracy);
    
    [self _startUpdates];
    
    if (copiedBlock && !self.timeoutShunted) {
        //after a timeout...
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^{
            if ([self _isBlockQueued:copiedBlock]) {
                //call the block with a fail, and provide old location
                copiedBlock(GBLocationFetchStateFailed, self.myLocation);
                
                //remove it from the array
                [self _removeBlock:copiedBlock];
            }
        });
    }
    
    return [GBLocationFetch cancelWithGBLocation:self block:copiedBlock];
}

#pragma mark - util

-(void)_gotNewLocation:(CLLocation *)location {
    if (location.horizontalAccuracy > 0 && location.horizontalAccuracy <= self.desiredAccuracy) {
        //remember the location
        self.myLocation = location;
        
        [self _processBlocksWithState:GBLocationFetchStateSuccess];
        
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

-(void)_processBlocksWithState:(GBLocationFetchState)state {
    //go through all the blocks, call them
    for (DidFetchLocationBlock block in self.didFetchLocationBlockHandlers) {
        block(state, self.myLocation);
    }
    
    //reset the array (it's lazy)
    self.didFetchLocationBlockHandlers = nil;
}

-(BOOL)_isBlockQueued:(DidFetchLocationBlock)block {
    if (block) {
        return [self.didFetchLocationBlockHandlers containsObject:block];
    }
    else {
        return NO;
    }
}

-(void)_addBlock:(DidFetchLocationBlock)block {
    if (block) {
        //add a copy to our array
        [self.didFetchLocationBlockHandlers addObject:block];
    }
}

-(void)_removeBlock:(DidFetchLocationBlock)block {
    if (block) {
        //remove it from our array
        [self.didFetchLocationBlockHandlers removeObject:block];
    }
}

@end
