//
//  DVDNetInsightTracking.m
//  NetInsightAnalytics
//
//  Created by Dave van Dugteren on 19/08/12.
//  Copyright (c) 2012 MrDaveNZ. All rights reserved.
//

#import "DVDNetInsightTracking.h"
#import "ASIFormDataRequest.h"
#import "ASIHTTPRequest.h"

@implementation DVDNetInsightTracking

#include

#define VERSION (3.7)

@implementation NetInsightTracking

@synthesize locationManager;
@synthesize bestEffortAtLocation;
@synthesize pageNamed, postalCode;
#pragma mark Maps

- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFindPlacemark:(MKPlacemark *)placemark{
  
  self.postalCode = [placemark postalCode];
  
  [self fireOffData];
}

- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFailWithError:(NSError *)error{
  
  self.postalCode = @"-1";
  
  [self fireOffData];
}

#pragma mark Location Manager Interactions

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
  
  NSTimeInterval locationAge = -[newLocation.timestamp timeIntervalSinceNow];
  if (locationAge &gt; 5.0) return;
  
  if (newLocation.horizontalAccuracy &lt; 0) return;
  
  if (bestEffortAtLocation == nil || bestEffortAtLocation.horizontalAccuracy &gt; newLocation.horizontalAccuracy) {
    
    self.bestEffortAtLocation = newLocation;
    
    if (newLocation.horizontalAccuracy &lt;= locationManager.desiredAccuracy) {
      
      [self stopUpdatingLocation:NSLocalizedString(@"Acquired Location", @"Acquired Location")];
      
      [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopUpdatingLocation:) object:nil];
    }
  }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
  
  self.postalCode = @"-1";
  
  if ([error code] != kCLErrorLocationUnknown) {
    [self stopUpdatingLocation:NSLocalizedString(@"Error", @"Error")];
    
  }
  
  [self fireOffData];
}

- (void)stopUpdatingLocation:(NSString *)state {
  
  [locationManager stopUpdatingLocation];
  locationManager.delegate = nil;
  
  if (self.bestEffortAtLocation.coordinate.latitude != 0) {
    MKReverseGeocoder *reverseGeoCode = [[MKReverseGeocoder alloc] initWithCoordinate: self.bestEffortAtLocation.coordinate];
    reverseGeoCode.delegate = self;
    [reverseGeoCode start];
  }
}

//SHouldn't actually create itself here.
- (id)init
{
  self = [super init];
  if (self) {
    // Initialization code here.
  }
  
  return self;
}

+ (NetInsightTracking *)sharedSingleton
{
  static NetInsightTracking *sharedSingleton;
  
  @synchronized(self)
  {
    if (!sharedSingleton)
      sharedSingleton = [[NetInsightTracking alloc] init];
    
    return sharedSingleton;
  }
}

- (void) fireOffData{
  NSString *stringApplication = [NSString stringWithFormat: @"https://[YOURURL]/%@", self.pageNamed];
  
  NSNumber *timeStampObj = [NSNumber numberWithDouble: [[NSDate date] timeIntervalSince1970]];
  
  CGRect screenBounds = [[UIScreen mainScreen] bounds];
  
  CGFloat screenScale = [[UIScreen mainScreen] scale];
  
  CGSize screenSize = CGSizeMake(screenBounds.size.width * screenScale, screenBounds.size.height * screenScale);
  
  NSString *rs = [NSString stringWithFormat: @"%.0fx%.0f", screenSize.width, screenSize.height];
  
  NSString *udid = [[UIDevice currentDevice] uniqueIdentifier];
  
  NSString *appv= [NSString stringWithFormat: @"%.1f", VERSION];
  
  if (self.postalCode == nil) {
    self.postalCode = @"-1";
  }
  
  NSString *geoLocation = self.postalCode;
  
  NSString *urlString =  [NSString stringWithFormat: @"[YOURURL]/images/ntpagetag.gif?lc=%@&amp;ts=%@&amp;rs=%@&amp;ck=%@&amp;wbc-from=%@&amp;wbc-linkpos=%@",
                          [stringApplication stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                          [[timeStampObj description] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                          [rs stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding],
                          [udid stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding],
                          [appv stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding],
                          [geoLocation stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
  
  NSURL *url = [NSURL URLWithString: urlString];
  
  ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
  
  [request setDelegate:self];
  [request startAsynchronous];
}

- (void) NetInsightTrack : (NSString *) pageName{
  
  self.pageNamed       = pageName;
  
  /*
   Only get Location Once.
   */
  
  if ((postalCode == @"-1") || (postalCode == nil)) {
    
    self.locationManager = [[[CLLocationManager alloc] init] autorelease];
    
    locationManager.delegate = self;
    
    locationManager.desiredAccuracy = [[NSNumber numberWithDouble:kCLLocationAccuracyHundredMeters] doubleValue];
    
    [locationManager startUpdatingLocation];
    
    [self performSelector:@selector(stopUpdatingLocation:) withObject:@"Timed Out" 
               afterDelay:30.0];
  }
  else{
    [self fireOffData];
  }
}

- (void)requestFinished:(ASIHTTPRequest *)request
{
  NSLog(@"%@", [request responseString]);
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
  NSError *error = [request error];
  NSLog(@"error: %@", [error description]);
}

@end
