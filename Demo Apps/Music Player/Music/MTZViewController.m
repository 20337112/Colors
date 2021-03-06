//
//  MTZViewController.m
//  Music
//
//  Created by Matt Zanchelli on 9/2/13.
//  Copyright (c) 2013 Matt Zanchelli. All rights reserved.
//

#import "MTZViewController.h"
#import "MTZSlider.h"

#define IPAD_MOTION_FX 1
#define IPAD_MOTION_FX_DIST 50

@import MediaPlayer;

#import <Colors/Colors.h>

typedef NS_ENUM(NSInteger, MTZMusicPlayerSongChangeDirection) {
	/// If the direction of song change in the playlist is unknown.
	/// @discussion This will occur when first starting to play an item.
	MTZMusicPlayerSongChangeUnknown = 0,
	/// If the direction of song change in the playlist is forwards (i.e. the player is advancing).
	MTZMusicPlayerSongChangeAdvance = 1,
	/// If the direction of song change in the playlist is backwards (i.e. the player is retreating).
	MTZMusicPlayerSongChangeRetreat = -1,
};

MTZMusicPlayerSongChangeDirection MTZMusicPlayerSongChangeDirectionFromIndexToIndex(NSUInteger fromIndex, NSUInteger toIndex)
{
	if ( fromIndex == NSNotFound || fromIndex == toIndex ) {
		return MTZMusicPlayerSongChangeUnknown;
	}
	
	if ( toIndex > fromIndex ) {
		return MTZMusicPlayerSongChangeAdvance;
	} else {
		return MTZMusicPlayerSongChangeRetreat;
	}
}

@interface MTZViewController () <MPMediaPickerControllerDelegate>

@property (strong, nonatomic) MPMusicPlayerController *player;

/// The index of the currently playing item.
/// @dicussion
@property (nonatomic) NSUInteger indexOfNowPlayingItem;

/// The primary image view for showing album artwork.
@property (strong, nonatomic) IBOutlet UIImageView *iv;

@property (weak, nonatomic) IBOutlet UIView *overlayView;

@property (strong, nonatomic) IBOutlet MTZSlider *trackSlider;
@property (strong, nonatomic) IBOutlet MTZSlider *volumeSlider;

@property (strong, nonatomic) IBOutlet UILabel *trackTitle;
@property (strong, nonatomic) IBOutlet UILabel *artistAndAlbumTitles;

@property (strong, nonatomic) UILabel *trackNumbersLabel;

@property (strong, nonatomic) IBOutlet UINavigationBar *navigationBar;

@property (strong, nonatomic) IBOutlet UIView *controlsView;

@property (strong, nonatomic) IBOutlet UIImageView *topShadow;
@property (strong, nonatomic) IBOutlet UIImageView *bottomShadow;

@property (strong, nonatomic) IBOutlet UILabel *timeElapsed;
@property (strong, nonatomic) IBOutlet UILabel *timeRemaining;

@property (strong, nonatomic) IBOutlet UIButton *playPause;

@property (strong, nonatomic) MPMediaPickerController *mediaPicker;

@property (strong, nonatomic) NSTimer *pollElapsedTime;

@property (strong, nonatomic) IBOutlet UIImageView *speakerOffImage;

@end

@implementation MTZViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	_player = [MPMusicPlayerController iPodMusicPlayer];
	_indexOfNowPlayingItem = [_player indexOfNowPlayingItem];
	
	UIUserInterfaceIdiom idiom = UIDevice.currentDevice.userInterfaceIdiom;
	switch ( idiom ) {
		case UIUserInterfaceIdiomPad: {
			_trackSlider.inset = 0;
#if IPAD_MOTION_FX
			// Album art has motion effects
			CGFloat motion = IPAD_MOTION_FX_DIST;
			
			UIInterpolatingMotionEffect *verticalMotion = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
			verticalMotion.minimumRelativeValue = @(motion);
			verticalMotion.maximumRelativeValue = @(motion * -1);
			
			UIInterpolatingMotionEffect *horizontalMotion = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
			horizontalMotion.minimumRelativeValue = @(motion);
			horizontalMotion.maximumRelativeValue = @(motion * -1);
			
			_iv.motionEffects = @[verticalMotion, horizontalMotion];
#endif
			
		} break;
		case UIUserInterfaceIdiomPhone:
		default: {
			// Track Slider has special features for iPhone/iPod touch
			_trackSlider = [[MTZSlider alloc] initWithFrame:(CGRect){52,1,216,34}];
			_trackSlider.inset = 3;
			[_trackSlider addTarget:self
							 action:@selector(trackSliderChangedValue:)
				   forControlEvents:UIControlEventValueChanged];
			[_trackSlider addTarget:self
							 action:@selector(trackSliderDidBegin:)
				   forControlEvents:UIControlEventTouchDown];
			[_trackSlider addTarget:self
							 action:@selector(trackSliderDidEnd:)
				   forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchDragExit|UIControlEventTouchCancel];
			_trackSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			[_controlsView addSubview:_trackSlider];
			
			// Volume slider only present on iPhone/iPod touch
			_volumeSlider = [[MTZSlider alloc] initWithFrame:(CGRect){52,121,216,34}];
			[_volumeSlider addTarget:self
							  action:@selector(volumeChanged:)
					forControlEvents:UIControlEventValueChanged];
			_volumeSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			_volumeSlider.value = _player.volume;
			_volumeSlider.inset = 3;
			_volumeSlider.fillImage = [UIImage imageNamed:@"VolumeFill"];
			_volumeSlider.trackImage = [UIImage imageNamed:@"VolumeTrack"];
			[_volumeSlider setThumbImage:[UIImage imageNamed:@"VolumeThumb"]
								forState:UIControlStateNormal];
			[_controlsView addSubview:_volumeSlider];
			
			
			// Top and bottom shadows have very subtle motion effects
			UIInterpolatingMotionEffect *verticalMotion = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
			verticalMotion.minimumRelativeValue = @2;
			verticalMotion.maximumRelativeValue = @-2;
			_topShadow.motionEffects = @[verticalMotion];
			_bottomShadow.motionEffects = @[verticalMotion];
			
			
			// Show track numbers in title
			_trackNumbersLabel = [[UILabel alloc] initWithFrame:(CGRect){0,0,160,32}];
			_trackNumbersLabel.textAlignment = NSTextAlignmentCenter;
			_trackNumbersLabel.text = @"Now Playing";
			
			self.navigationBar.topItem.titleView = _trackNumbersLabel;
			[self.navigationBar.topItem setHidesBackButton:NO animated:NO];
			
			// Add volume view to hide volume HUD when changing volume
			MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-1280.0, -1280.0, 0.0f, 0.0f)];
			[self.view addSubview:volumeView];
			
		} break;
	}
	
	// Set the track, fill, and thumb images for the slider
	_trackSlider.fillImage = [UIImage imageNamed:@"ProgressFill"];
	_trackSlider.trackImage = [UIImage imageNamed:@"ProgressTrack"];
	[_trackSlider setThumbImage:[UIImage imageNamed:@"ProgressThumb"]
					   forState:UIControlStateNormal];
	
	_mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeMusic];
    _mediaPicker.delegate = self;
    _mediaPicker.allowsPickingMultipleItems = YES;
	
	// Register for media player notifications
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(songChanged:)
                               name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification
                             object:_player];
	[notificationCenter addObserver:self
						   selector:@selector(playbackStateDidChange:)
							   name:MPMusicPlayerControllerPlaybackStateDidChangeNotification
							 object:_player];
	[notificationCenter addObserver:self
						   selector:@selector(volumeDidChange:)
							   name:MPMusicPlayerControllerVolumeDidChangeNotification
							 object:_player];
    [_player beginGeneratingPlaybackNotifications];
	
	[self checkPlaybackStatus];
	[self updatePlaybackTime];
}

- (BOOL)prefersStatusBarHidden
{
	UIUserInterfaceIdiom idiom = UIDevice.currentDevice.userInterfaceIdiom;
	
	switch ( idiom ) {
		case UIUserInterfaceIdiomPad:
			return YES;
		case UIUserInterfaceIdiomPhone:
		default:
			return NO;
	}
}

- (void)checkPlaybackStatus
{
	if ( _player.playbackState == MPMusicPlaybackStatePlaying ) {
		[_playPause setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
	} else {
		[_playPause setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
	}
}

- (void)songChanged:(id)sender
{
	[self updateAlbumArtworkAndTheme];
	
	MPMediaItem *currentItem = [_player nowPlayingItem];
	NSString *trackTitle = [currentItem valueForProperty:MPMediaItemPropertyTitle];
	if ( !trackTitle ) trackTitle = @"Song";
	_trackTitle.text = trackTitle;
	NSString *artist = [currentItem valueForProperty:MPMediaItemPropertyArtist];
	if ( !artist ) artist = @"Artist";
	NSString *album = [currentItem valueForProperty:MPMediaItemPropertyAlbumTitle];
	if ( !album ) album = @"Album";
	_artistAndAlbumTitles.text = [NSString stringWithFormat:@"%@ — %@", artist, album];
	
	
	NSNumber *trackNo = [currentItem valueForProperty:MPMediaItemPropertyAlbumTrackNumber];
	NSNumber *trackOf = [currentItem valueForProperty:MPMediaItemPropertyAlbumTrackCount];
	
	if ( trackNo && trackOf ) {
		NSString *title = [NSString stringWithFormat:@"%@ of %@", trackNo, trackOf];
		NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:title];
		NSUInteger length = [NSString stringWithFormat:@"%@", trackNo].length;
		[attributedTitle addAttribute:NSFontAttributeName
								value:[UIFont boldSystemFontOfSize:15.0f]
								range:NSMakeRange(0, length)];
		[attributedTitle addAttribute:NSFontAttributeName
								value:[UIFont systemFontOfSize:15.0f]
								range:NSMakeRange(length, 4)];
		[attributedTitle addAttribute:NSFontAttributeName
								value:[UIFont boldSystemFontOfSize:15.0f]
								range:NSMakeRange(length + 4, [NSString stringWithFormat:@"%@", trackOf].length)];
		_trackNumbersLabel.attributedText = attributedTitle;
	} else {
		_trackNumbersLabel.text = @"Now Playing";
	}
	
	NSNumber *playbackDuration = [currentItem valueForProperty:MPMediaItemPropertyPlaybackDuration];
	_trackSlider.maximumValue = playbackDuration.floatValue;
	
	[self updatePlaybackTime];
}

- (void)updateAlbumArtworkAndTheme
{
	// Get the current media item.
	MPMediaItem *currentItem = [_player nowPlayingItem];
	
	// Get the artwork
    MPMediaItemArtwork *artwork = [currentItem valueForProperty:MPMediaItemPropertyArtwork];
	UIImage *albumArtwork = [artwork imageWithSize:CGSizeMake(320, 320)];
	
	// The previous value of the index.
	NSUInteger prev = self.indexOfNowPlayingItem;
	// Update the value.
	self.indexOfNowPlayingItem = [_player indexOfNowPlayingItem];
	
	// Find the direction of track changes and use this to flip animation.
	MTZMusicPlayerSongChangeDirection direction = MTZMusicPlayerSongChangeDirectionFromIndexToIndex(prev, self.indexOfNowPlayingItem);
	
	CGRect mainArtFrame = _iv.frame;
	
	UIImageView *albumArtworkOut = [[UIImageView alloc] initWithFrame:mainArtFrame];
	albumArtworkOut.image = _iv.image;
	[self.view insertSubview:albumArtworkOut aboveSubview:_iv];
	
	UIImageView *albumArtworkIn = [[UIImageView alloc] initWithFrame:CGRectOffset(mainArtFrame, direction * mainArtFrame.size.width, 0)];
	albumArtworkIn.image = albumArtwork;
	[self.view insertSubview:albumArtworkIn aboveSubview:_iv];
	
	[UIView animateWithDuration:0.7f
						  delay:0.0f
		 usingSpringWithDamping:1.0f
		  initialSpringVelocity:1.0f
						options:UIViewAnimationOptionBeginFromCurrentState
					 animations:^{
						 albumArtworkOut.frame = CGRectOffset(mainArtFrame, direction * -mainArtFrame.size.width, 0);
						 albumArtworkIn.frame = mainArtFrame;
					 }
					 completion:^(BOOL finished) {
						 [albumArtworkOut removeFromSuperview];
						 [albumArtworkIn removeFromSuperview];
					 }];
	
	_iv.image = albumArtwork;
	
	[UIView animateWithDuration:0.3f
						  delay:0.0f
						options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
					 animations:^{
#warning does not *animate* tint color changes to volume slider (iPhone)
						 [self refreshColors];
					 }
					 completion:^(BOOL finished) {
					 }];
}

- (void)updatePlaybackTime
{
	[self updatePlaybackTimeForTime:_player.currentPlaybackTime withAnimation:NO];
}

- (void)updatePlaybackTimeWithAnimation
{
	[self updatePlaybackTimeForTime:_player.currentPlaybackTime withAnimation:YES];
}

- (void)updatePlaybackTimeForTime:(NSTimeInterval)elapsed withAnimation:(BOOL)animated
{
	if ( animated ) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationBeginsFromCurrentState:YES];
		[UIView setAnimationCurve:UIViewAnimationCurveLinear];
		[UIView setAnimationDuration:1.0f];
		[_trackSlider setValue:(elapsed + 0.5f) animated:YES];
		[UIView commitAnimations];
	} else {
		[_trackSlider setValue:(elapsed) animated:NO];
	}
	
	CGFloat minutes, seconds;
	NSString *secondsString, *minutesString;
	
	minutes = floor(elapsed / 60);
	seconds = roundf(elapsed - minutes * 60);
	if ( isnan(seconds) ) {
		secondsString = @"--";
	} else if ( seconds < 10 ) {
		secondsString = [NSString stringWithFormat:@"0%.0f", seconds];
	} else {
		secondsString = [NSString stringWithFormat:@"%.0f", seconds];
	}
	
	if ( isnan(minutes) ) {
		minutesString = @"--";
	} else {
		minutesString = [NSString stringWithFormat:@"%.0f", MAX(0,minutes)];
	}
	
	_timeElapsed.text = [NSString stringWithFormat:@"%@:%@", minutesString, secondsString];
	
	MPMediaItem *currentItem = [_player nowPlayingItem];
	NSNumber *playbackDuration = [currentItem valueForProperty:MPMediaItemPropertyPlaybackDuration];
	
#warning round playbackDuration to nearest second?
	NSTimeInterval remaining = playbackDuration.floatValue - elapsed;
	minutes = floor(remaining / 60);
	seconds = round(remaining - minutes * 60);
	if ( isnan(seconds) ){
		secondsString = @"--";
	} else if ( seconds < 10 ) {
		secondsString = [NSString stringWithFormat:@"0%.0f", seconds];
	} else {
		secondsString = [NSString stringWithFormat:@"%.0f", seconds];
	}
	
	if ( isnan(minutes) ) {
		minutesString = @"--";
	} else {
		minutesString = [NSString stringWithFormat:@"-%.0f", MAX(0,minutes)];
	}
	
	_timeRemaining.text = [NSString stringWithFormat:@"%@:%@", minutesString, secondsString];
}

- (void)playbackStateDidChange:(id)sender
{
	switch ( _player.playbackState ) {
		case MPMusicPlaybackStateStopped:
			[_player stop];
		case MPMusicPlaybackStatePaused:
			[_playPause setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
			[_pollElapsedTime invalidate];
			_pollElapsedTime = nil;
			break;
		case MPMusicPlaybackStatePlaying:
			[_playPause setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
			[_pollElapsedTime invalidate];
			_pollElapsedTime = nil;
			_pollElapsedTime = [NSTimer scheduledTimerWithTimeInterval:1.0f
																target:self
															  selector:@selector(updatePlaybackTime)
															  userInfo:nil
															   repeats:YES];
			break;
		default:
			break;
	}
}

- (void)volumeDidChange:(id)sender
{
	_volumeSlider.value = _player.volume;
}

- (void)refreshColors
{
	UIUserInterfaceIdiom idiom = UIDevice.currentDevice.userInterfaceIdiom;
	
	switch ( idiom ) {
		case UIUserInterfaceIdiomPad: {
			[self refreshColorsForIdiomPad];
		} break;
		case UIUserInterfaceIdiomPhone:
		default: {
			[self refreshColorsForIdiomPhone];
		} break;
	}
}

- (void)refreshColorsForIdiomPhone
{
#warning animate this change? Animate the change of album art (if it changes), too?
	UIColor *keyColor = [_iv.image keyColorToContrastAgainstColors:@[[UIColor whiteColor]]
											   withMinimumContrast:UIColorContrastLevelLow];
	
	if ( keyColor ) {
		[[UIApplication sharedApplication] keyWindow].tintColor = keyColor;
		_trackSlider.tintColor = keyColor;
		_volumeSlider.tintColor = keyColor;
	} else {
#warning is there a better way to only run this if keyColor is nil?
		UIColor *bg = [_iv.image backgroundColorToContrastAgainstColors:@[[UIColor whiteColor],
																	      [UIColor lightGrayColor]]
													withMinimumContrast:UIColorContrastLevelLow];
		// Default to dark gray color for sliders
		if ( !bg ) {
			bg = [UIColor neueGray];
		}
		
		[[UIApplication sharedApplication] keyWindow].tintColor = [UIColor neueBlue];
		_trackSlider.tintColor = bg;
		_volumeSlider.tintColor = bg;
	}
}

- (void)refreshColorsForIdiomPad
{
#warning position album art vertically to maximize contrast of text against that part of image?
#warning use cropped image (only part that appears on screen)?
	UIColor *bg = [_iv.image backgroundColorToContrastAgainstColors:@[[UIColor whiteColor]]
												withMinimumContrast:UIColorContrastLevelMedium];
	// Default to black otherwise
	bg = (bg) ? bg : UIColor.blackColor;
	_overlayView.backgroundColor = bg;
	
	UIColor *keyColor = [_iv.image backgroundColorToContrastAgainstColors:@[bg, [UIColor blackColor]]
												   withMinimumContrast:UIColorContrastLevelMedium];
	
	// Default to white otherwise
	keyColor = (keyColor) ? keyColor : UIColor.whiteColor;
	
	[[UIApplication sharedApplication] keyWindow].tintColor = keyColor;
	_trackSlider.tintColor = keyColor;
}

- (IBAction)didSwipe:(UISwipeGestureRecognizer *)sender
{
	switch ( sender.direction ) {
		case UISwipeGestureRecognizerDirectionRight: {
			[self previous:sender];
		} break;
		case UISwipeGestureRecognizerDirectionLeft: {
			[self skip:sender];
		} break;
		default:
			break;
	}
}


- (IBAction)playPause:(id)sender
{
	if ( _player.playbackState == MPMusicPlaybackStatePlaying ) {
        [_player pause];
    } else {
        [_player play];
    }
}

- (IBAction)skip:(id)sender
{
	[_player skipToNextItem];
}

- (IBAction)fastForward:(UILongPressGestureRecognizer *)sender
{
#warning this should behave differently if paused (do not show change in play/pause)
	switch (sender.state) {
		case UIGestureRecognizerStateBegan:
			[_player beginSeekingForward];
			break;
		case UIGestureRecognizerStateEnded:
			[_player endSeeking];
			break;
		default:
			break;
	}
}

- (IBAction)previous:(id)sender
{
	[_player skipToPreviousItem];
}

- (IBAction)rewind:(UILongPressGestureRecognizer *)sender
{
#warning this should behave differently if paused (do not show change in play/pause)
	switch (sender.state) {
		case UIGestureRecognizerStateBegan:
			[_player beginSeekingBackward];
			break;
		case UIGestureRecognizerStateEnded:
			[_player endSeeking];
			break;
		default:
			break;
	}
}

- (IBAction)trackSliderDidBegin:(id)sender
{
	// Stop timer
	[_pollElapsedTime invalidate];
	_pollElapsedTime = nil;
}

- (IBAction)trackSliderDidEnd:(id)sender
{
	// Start timer back up
	[_pollElapsedTime invalidate];
	_pollElapsedTime = nil;
	_pollElapsedTime = [NSTimer scheduledTimerWithTimeInterval:1.0f
														target:self
													  selector:@selector(updatePlaybackTimeWithAnimation)
													  userInfo:nil
													   repeats:YES];
}

- (IBAction)trackSliderChangedValue:(id)sender
{
	[self updatePlaybackTimeForTime:_trackSlider.value withAnimation:NO];
	_player.currentPlaybackTime = _trackSlider.value;
}

- (IBAction)volumeChanged:(id)sender
{
	_player.volume = _volumeSlider.value;
}

- (IBAction)didTapRightBarButtonItem:(id)sender
{
	/*
	 // Testing showing an action sheet to test tintColor change of items on screen.
	 UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@""
	 delegate:Nil
	 cancelButtonTitle:@"Cancel"
	 destructiveButtonTitle:nil
	 otherButtonTitles:nil];
	 [as showFromBarButtonItem:sender animated:YES];
	 */
	
	[self presentViewController:_mediaPicker
					   animated:YES
					 completion:^{}];
}


#pragma mark Media Picker

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker
  didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection
{
    if ( mediaItemCollection ) {
        [_player setQueueWithItemCollection:mediaItemCollection];
        [_player play];
    }
	[mediaPicker dismissViewControllerAnimated:YES
									completion:^{}];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker
{
	[mediaPicker dismissViewControllerAnimated:YES
									completion:^{}];
}


#pragma mark View Controller end

- (void)dealloc
{
#warning unregister notifications?
	[_player endGeneratingPlaybackNotifications];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
