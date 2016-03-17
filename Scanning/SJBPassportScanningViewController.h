//
//  SJBPassportScanningViewController
//
//
//  Created by yiliu on 21/8/15.
//  Copyright (c) 2015年 mikedu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <TesseractOCR/TesseractOCR.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <opencv2/imgproc/imgproc_c.h>


@interface SJBPassportScanningViewController : UIViewController

@property (nonatomic, assign) id delegate;

//背景图片名
@property (nonatomic, assign) NSString * backGroundImageName;

//扫描线图片名
@property (nonatomic, assign) NSString * scanningLineImageName;

//扫描框的位置和尺寸
@property (nonatomic, assign) CGRect scanningFrameRect;

//扫描线图片的大小
@property (nonatomic, assign) CGSize scanningLineSize;

@end


@protocol SJBPassportScanningDelegate <NSObject>

@required
-(void)passportScanningSuccessfull:(SJBPassportScanningViewController *)scanViewController secondName:(NSString *)secondName firstName:(NSString *)firstName sex:(NSString *)sex birthDay:(NSString *)birthDay nation:(NSString *)nation passportNumber:(NSString *)passportNumber valideDate:(NSString *)validDate usedTime:(NSString *)usedTime;
-(void)passportScanningCancelled:(SJBPassportScanningViewController *)scanViewController;


@end