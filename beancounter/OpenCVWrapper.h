//
//  OpenCVWrapper.h
//  beancounter
//
//  Created by Joakim Beijar on 25.02.2018.
//  Copyright © 2018 Joakim Beijar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OpenCVWrapper : NSObject
+ (NSArray*)detectCircles:(void *)buffer width:(int)width height:(int)height rowLength:(int)rowLength minRadius:(int)minRadius maxRadius:(int)maxRadius;
@end
    
