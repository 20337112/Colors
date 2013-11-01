//
//  UIColor+KeyColor.h
//  Colors
//
//  Created by Matt on 10/30/13.
//  Copyright (c) 2013 Matt Zanchelli. All rights reserved.
//

@import UIKit;

@interface UIColor (KeyColor)

/// A Boolean value determining whether the receiving color would be appropriate to use as a key color.
/// @returns A Boolean value determing whether the receiving color would be appropriate to use as a key color.
/// @discussion This can be used to determine whether or not to use a color as the tintColor for an enabled user interface control. Do not rely on this to return the same value all of the time. Results may vary depending on user settings and ambient conditions. (Do not store the return value for an extended period of time).
- (BOOL)isKeyColorAppropriate;

/// Find the first color in the provided array that is key color appropriate.
/// @param colors An ordered array of possible colors.
/// @return The first color in the array that is key color appropriate. Returns nil if no color is key color appropriate.
/// @discussion This is useful for determining which color to use as the tintColor for an enabled user interface control. This method will likely be used when determining if the hardware color or user wallpaper color is appropriate to use.
+ (UIColor *)firstKeyColor:(NSArray *)colors;

@end