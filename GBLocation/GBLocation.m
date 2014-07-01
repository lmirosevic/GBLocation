//
//  GBLocation.m
//  GBLocation
//
//  Created by Luka Mirosevic on 21/06/2013.
//  Copyright (c) 2013 Goonbee. All rights reserved.
//

#import "GBLocation.h"

NSTimeInterval const kGBLocationAlwaysFetchFreshLocation =  0.0;

static NSTimeInterval const kDefaultTimeout =			    4;
#define kDefaultDesiredAccuracy                             kCLLocationAccuracyKilometer

static NSTimeInterval const kPermissionCheckPeriod =        1./5.;// 5 times/sec

@interface GBLocationFetch ()

@property (weak, nonatomic) DidFetchLocationBlock       block;
@property (weak, nonatomic) GBLocation                  *GBLocation;

+(GBLocationFetch *)cancelWithGBLocation:(GBLocation *)GBLocation block:(DidFetchLocationBlock)block;
-(id)initWithGBLocation:(GBLocation *)GBLocation block:(DidFetchLocationBlock)block;

@end

@interface GBLocation () <CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager         *locationManager;
@property (strong, nonatomic) NSMutableArray            *didFetchLocationBlockHandlers;
@property (assign, nonatomic) CLLocationAccuracy        desiredAccuracy;

@property (strong, nonatomic) NSMutableArray            *deferredHandlers;
@property (strong, nonatomic) NSTimer                   *permissionCheckTimer;
@property (assign, nonatomic) NSTimeInterval            lastLocationFetchTime;

-(void)_removeBlock:(DidFetchLocationBlock)block;
-(void)_removeDeferredBlock:(DidFetchLocationBlock)block;

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
    
    //remove block from committed queue
    [self.GBLocation _removeBlock:self.block];
    
    //remove block from deferred queue
    [self.GBLocation _removeDeferredBlock:self.block];
    
    self.block = nil;//just for good measure... but we're weak so it shouldn't make a difference for mem management
}

@end

@implementation GBLocation

#pragma mark - CA

-(CLLocation *)myLocation {
    return self.locationManager.location;
}

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
        self.locationManager.distanceFilter = kCLDistanceFilterNone;
        if ([self.locationManager respondsToSelector:@selector(setPausesLocationUpdatesAutomatically:)]) [self.locationManager setPausesLocationUpdatesAutomatically:NO];//ios 6 only
        
        self.desiredAccuracy = kDefaultDesiredAccuracy;
        self.timeout = kDefaultTimeout;
        self.refreshInterval = kGBLocationAlwaysFetchFreshLocation;
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
    //instantly call the block with cached location if locatoin refresh time is not expired yet
    NSTimeInterval currentTime = [[NSProcessInfo processInfo] systemUptime];
    if(self.myLocation && self.lastLocationFetchTime + self.refreshInterval > currentTime) {
	    if (block) block(GBLocationFetchStateSuccess, self.myLocation);
        return nil;
    }
    self.lastLocationFetchTime = currentTime;
    
    //set the desired accuracy
    self.desiredAccuracy = accuracy;
    
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusAuthorized: {
            //copy the block
            DidFetchLocationBlock copiedBlock = [block copy];
            
            //store block
            [self _addBlock:copiedBlock];
            
            //start updates
            [self _startUpdates];
            
            //set up timeout block
            [self _activateTimeoutForBlock:copiedBlock];
            
            //return a cancel deferrable for the block
            return [GBLocationFetch cancelWithGBLocation:self block:copiedBlock];
        } break;
            
        case kCLAuthorizationStatusNotDetermined: {
            //copy the block
            DidFetchLocationBlock copiedBlock = [block copy];
            
            //start the permission watch and defer the block timeout activation
            [self _startPermissionWatchAndDeferBlock:copiedBlock];
            
            //start updates, so that the notification view is presented to the user, and the immediately stop it (once authorisation is granted, it will be restarted)
            [self _startUpdates];
            [self _stopUpdates];
            
            //return a cancel deferrable for the block
            return [GBLocationFetch cancelWithGBLocation:self block:copiedBlock];
        } break;
            
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted: {
            //we don't have auth, so we failed
            if (block) block(GBLocationFetchStateFailed, self.myLocation);
            
            return nil;
        } break;
    }
}

#pragma mark - util

-(void)_startPermissionWatchAndDeferBlock:(DidFetchLocationBlock)block {
    //create the array if we don't have one yet
    if (!self.deferredHandlers) {
        self.deferredHandlers = [NSMutableArray new];
    }
    
    //store the block, if we got one
    [self _addDeferredBlock:block];
    
    //start permission checking, if it's not already ongoing
    if (!self.permissionCheckTimer) {
        self.permissionCheckTimer = [NSTimer scheduledTimerWithTimeInterval:kPermissionCheckPeriod target:self selector:@selector(_checkPermission) userInfo:nil repeats:YES];
    }
}

-(void)_checkPermission {
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusAuthorized: {
            [self _stopPermissionTimer];
            [self _receivedPermission];
        } break;
            
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted: {
            [self _stopPermissionTimer];
            [self _deniedPermission];
        } break;
            
        case kCLAuthorizationStatusNotDetermined: {
            //noop, keep going
        } break;
    }
}

-(void)_stopPermissionTimer {
    [self.permissionCheckTimer invalidate];
    self.permissionCheckTimer = nil;
}

-(void)_receivedPermission {
    //commit all the deferred blocks, and activate their timeouts
    [self _commitDeferredBlocks];
    
    //start updates
    [self _startUpdates];
}

-(void)_deniedPermission {
    //fail all the deferred block
    [self _failDeferredBlocks];
}

-(void)_commitDeferredBlocks {
    for (DidFetchLocationBlock block in self.deferredHandlers) {
        //add it the real handlers
        [self _addBlock:block];
        
        //activate the timeout for him
        [self _activateTimeoutForBlock:block];
    }
    
    //clean up some mem
    self.deferredHandlers = nil;
}

-(void)_failDeferredBlocks {
    for (DidFetchLocationBlock block in self.deferredHandlers) {
        block(GBLocationFetchStateFailed, self.myLocation);
    }
    
    //clean up some mem
    self.deferredHandlers = nil;
}

-(void)_activateTimeoutForBlock:(DidFetchLocationBlock)block {
    if (block) {
        //after a timeout...
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^{
            if ([self _isBlockQueued:block]) {//we need to check because the block might have been cancelled, in which case we don't want to fail it since it's already been processed with a cancelled flag
                //call the block with a fail, and provide old location
                block(GBLocationFetchStateFailed, self.myLocation);
                
                //remove it from the array
                [self _removeBlock:block];
            }
        });
    }
}

-(void)_gotNewLocation:(CLLocation *)location {
    //if the new location meets the accuracy requirement, then stop processing blocks (in the case this doesn't happen for a while, our timeout will kick in for us)
    if (location.horizontalAccuracy > 0 && location.horizontalAccuracy <= self.desiredAccuracy) {
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

-(void)_addDeferredBlock:(DidFetchLocationBlock)block {
    if (block) {
        //add a copy to our array
        [self.deferredHandlers addObject:block];
    }
}

-(void)_removeDeferredBlock:(DidFetchLocationBlock)block {
    if (block) {
        //remove it from our array
        [self.deferredHandlers removeObject:block];
    }
}

@end
