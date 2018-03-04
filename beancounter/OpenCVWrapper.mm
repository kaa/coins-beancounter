//
//  OpenCVWrapper.m
//  beancounter
//
//  Created by Joakim Beijar on 25.02.2018.
//  Copyright © 2018 Joakim Beijar. All rights reserved.
//

#import "OpenCVWrapper.h"

@implementation OpenCVWrapper
+ (NSArray*)detectCircles:(void *)buffer width:(int)width height:(int)height rowLength:(int)rowLength minRadius:(int)minRadius maxRadius:(int)maxRadius {
    cv::Mat img = cv::Mat(height,width,CV_8UC4,buffer,rowLength);
    cv::Mat gray = img;
    cv::cvtColor(img,gray,cv::COLOR_BGRA2GRAY);
    cv::GaussianBlur(gray, gray, cv::Size(5,5), 2,2);
    
    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(gray, circles, CV_HOUGH_GRADIENT, 1.2, 100.0, 200.0, minRadius*1.2, minRadius, maxRadius);

    NSMutableArray *hits = [NSMutableArray new];
    std::for_each(circles.begin(), circles.end(), ^(cv::Vec3f pt) {
        [hits addObject:@[
                          [NSNumber numberWithFloat:pt[0]],
                          [NSNumber numberWithFloat:pt[1]],
                          [NSNumber numberWithFloat:pt[2]]
                          ]];
    });
    return [NSArray arrayWithArray:hits];
}
@end
