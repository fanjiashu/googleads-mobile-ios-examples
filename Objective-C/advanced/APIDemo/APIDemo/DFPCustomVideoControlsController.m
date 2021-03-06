//
//  Copyright (C) 2018 Google, Inc.
//
//  DFPCustomVideoControlsController.m
//  APIDemo
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "DFPCustomVideoControlsController.h"

static NSString *const TestAdUnit = @"/6499/example/native-video";
static NSString *const TestNativeCustomTemplateID = @"10104090";

@interface DFPCustomVideoControlsController () <GADUnifiedNativeAdLoaderDelegate,
                                                GADNativeCustomTemplateAdLoaderDelegate>

/// You must keep a strong reference to the GADAdLoader during the ad loading process.
@property(nonatomic, strong) GADAdLoader *adLoader;

/// The native ad view being presented.
@property(nonatomic, strong) UIView *nativeAdView;

@end

@implementation DFPCustomVideoControlsController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.versionLabel.text = [GADRequest sdkVersion];
  [self refreshAd:nil];
}

- (IBAction)refreshAd:(id)sender {
  // Loads an ad for any of unified native or custom native ads.
  NSMutableArray *adTypes = [[NSMutableArray alloc] init];
  if (self.unifiedNativeAdSwitch.on) {
    [adTypes addObject:kGADAdLoaderAdTypeUnifiedNative];
  }
  if (self.customNativeAdSwitch.on) {
    [adTypes addObject:kGADAdLoaderAdTypeNativeCustomTemplate];
  }

  if (!adTypes.count) {
    NSLog(@"Error: You must specify at least one ad type to load.");
    return;
  }

  GADVideoOptions *videoOptions = [[GADVideoOptions alloc] init];
  videoOptions.startMuted = self.startMutedSwitch.on;
  videoOptions.customControlsRequested = self.requestCustomControlsSwitch.on;

  self.refreshButton.enabled = NO;
  self.adLoader = [[GADAdLoader alloc] initWithAdUnitID:TestAdUnit
                                     rootViewController:self
                                                adTypes:adTypes
                                                options:@[ videoOptions ]];
  [self.customControlsView resetWithStartMuted:videoOptions.startMuted];
  self.adLoader.delegate = self;
  [self.adLoader loadRequest:[DFPRequest request]];
}

- (void)setAdView:(UIView *)view {
  // Remove previous ad view.
  [self.nativeAdView removeFromSuperview];
  self.nativeAdView = view;

  // Add new ad view and set constraints to fill its container.
  [self.placeholderView addSubview:view];
  [self.nativeAdView setTranslatesAutoresizingMaskIntoConstraints:NO];

  NSDictionary *viewDictionary = NSDictionaryOfVariableBindings(_nativeAdView);
  [self.placeholderView
      addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_nativeAdView]|"
                                                             options:0
                                                             metrics:nil
                                                               views:viewDictionary]];
  [self.placeholderView
      addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_nativeAdView]|"
                                                             options:0
                                                             metrics:nil
                                                               views:viewDictionary]];
}

#pragma mark GADAdLoaderDelegate implementation

- (void)adLoader:(GADAdLoader *)adLoader didFailToReceiveAdWithError:(GADRequestError *)error {
  NSLog(@"%@ failed with error: %@", adLoader, [error localizedDescription]);
  self.refreshButton.enabled = YES;
}

#pragma mark GADNativeCustomTemplateAdLoaderDelegate implementation

- (void)adLoader:(GADAdLoader *)adLoader
    didReceiveNativeCustomTemplateAd:(GADNativeCustomTemplateAd *)nativeCustomTemplateAd {
  NSLog(@"Received custom native ad: %@", nativeCustomTemplateAd);
  self.refreshButton.enabled = YES;

  // Create and place ad in view hierarchy.
  SimpleNativeAdView *simpleNativeAdView =
      [[NSBundle mainBundle] loadNibNamed:@"SimpleNativeAdView" owner:nil options:nil].firstObject;
  [self setAdView:simpleNativeAdView];

  // Populate the custom native ad view with its assets.
  [simpleNativeAdView populateWithCustomNativeAd:nativeCustomTemplateAd];

  self.customControlsView.controller = nativeCustomTemplateAd.videoController;
}

- (NSArray *)nativeCustomTemplateIDsForAdLoader:(GADAdLoader *)adLoader {
  return @[ TestNativeCustomTemplateID ];
}

#pragma mark GADUnifiedNativeAdLoaderDelegate implementation

- (void)adLoader:(GADAdLoader *)adLoader didReceiveUnifiedNativeAd:(GADUnifiedNativeAd *)nativeAd {
  NSLog(@"Received unified native ad: %@", nativeAd);
  self.refreshButton.enabled = YES;

  // Create and place ad in view hierarchy.
  GADUnifiedNativeAdView *nativeAdView =
      [[NSBundle mainBundle] loadNibNamed:@"UnifiedNativeAdView" owner:nil options:nil].firstObject;
  [self setAdView:nativeAdView];

  nativeAdView.nativeAd = nativeAd;

  // Populate the native ad view with the native ad assets.
  // Some assets are guaranteed to be present in every native ad.
  ((UILabel *)nativeAdView.headlineView).text = nativeAd.headline;
  ((UILabel *)nativeAdView.bodyView).text = nativeAd.body;
  [((UIButton *)nativeAdView.callToActionView)setTitle:nativeAd.callToAction
                                              forState:UIControlStateNormal];

  // Some native ads will include a video asset, while others do not. Apps can
  // use the GADVideoController's hasVideoContent property to determine if one
  // is present, and adjust their UI accordingly.

  // The UI for this controller constrains the image view's height to match the
  // media view's height, so by changing the one here, the height of both views
  // are being adjusted.
  if (nativeAd.videoController.hasVideoContent) {
    // The video controller has content. Show the media view.
    nativeAdView.mediaView.hidden = NO;
    nativeAdView.imageView.hidden = YES;

    // This app uses a fixed width for the GADMediaView and changes its height
    // to match the aspect ratio of the video it displays.
    if (nativeAd.videoController.aspectRatio > 0) {
      NSLayoutConstraint *heightConstraint =
          [NSLayoutConstraint constraintWithItem:nativeAdView.mediaView
                                       attribute:NSLayoutAttributeHeight
                                       relatedBy:NSLayoutRelationEqual
                                          toItem:nativeAdView.mediaView
                                       attribute:NSLayoutAttributeWidth
                                      multiplier:(1 / nativeAd.videoController.aspectRatio)
                                        constant:0];
      heightConstraint.active = YES;
    }
  } else {
    // If the ad doesn't contain a video asset, the first image asset is shown
    // in the image view. The existing lower priority height constraint is used.
    nativeAdView.mediaView.hidden = YES;
    nativeAdView.imageView.hidden = NO;

    GADNativeAdImage *firstImage = nativeAd.images.firstObject;
    ((UIImageView *)nativeAdView.imageView).image = firstImage.image;
  }
  self.customControlsView.controller = nativeAd.videoController;

  // These assets are not guaranteed to be present, and should be checked first.
  ((UIImageView *)nativeAdView.iconView).image = nativeAd.icon.image;
  nativeAdView.iconView.hidden = nativeAd.icon ? NO : YES;

  ((UIImageView *)nativeAdView.starRatingView).image = [self imageForStars:nativeAd.starRating];
  nativeAdView.starRatingView.hidden = nativeAd.starRating ? NO : YES;

  ((UILabel *)nativeAdView.storeView).text = nativeAd.store;
  nativeAdView.storeView.hidden = nativeAd.store ? NO : YES;

  ((UILabel *)nativeAdView.priceView).text = nativeAd.price;
  nativeAdView.priceView.hidden = nativeAd.price ? NO : YES;

  ((UILabel *)nativeAdView.advertiserView).text = nativeAd.advertiser;
  nativeAdView.advertiserView.hidden = nativeAd.advertiser ? NO : YES;

  // In order for the SDK to process touch events properly, user interaction
  // should be disabled.
  nativeAdView.callToActionView.userInteractionEnabled = NO;
}

/// Gets an image representing the number of stars. Returns nil if rating is less than 3.5 stars.
- (UIImage *)imageForStars:(NSDecimalNumber *)numberOfStars {
  double starRating = numberOfStars.doubleValue;
  if (starRating >= 5) {
    return [UIImage imageNamed:@"stars_5"];
  } else if (starRating >= 4.5) {
    return [UIImage imageNamed:@"stars_4_5"];
  } else if (starRating >= 4) {
    return [UIImage imageNamed:@"stars_4"];
  } else if (starRating >= 3.5) {
    return [UIImage imageNamed:@"stars_3_5"];
  } else {
    return nil;
  }
}

@end
