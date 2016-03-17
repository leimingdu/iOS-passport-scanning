//
//  SJBPassportScanningViewController.m
//  mikedu
//
//  Created by mikedu on 31/8/15.
//  Copyright (c) 2015年 mikedu. All rights reserved.
//

#import "SJBPassportScanningViewController.h"
#import <opencv2/imgproc/imgproc_c.h>
#import <opencv2/objdetect/objdetect.hpp>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#import <sys/sysctl.h>


#define DHLGD 0

const float screenWidth = [[UIScreen mainScreen] bounds].size.width;
const float screenHight = [[UIScreen mainScreen] bounds].size.height;

//由于在屏幕orientation的时候，screenWidth和screenHight会改变，这里做一个判断
const float VIEWHIGHT = screenWidth > screenHight ? screenWidth : screenHight;
const float VIEWWIDTH = screenWidth > screenHight ? screenHight : screenWidth;

NSString *tempPictureName = @"temp_saved_passport.png";

#define IPHONE6WIDTH 375.0f
#define IPHONE6HEIGHT 667.0f

const float scrennHeightRatio = VIEWHIGHT / IPHONE6HEIGHT;
const float scrennWidthRatio = VIEWWIDTH / VIEWWIDTH;




@interface SJBPassportScanningViewController ()<G8TesseractDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>
{
    NSString *_secondName;
    NSString *_firstName;
    NSString *_sex;
    NSString *_birthDay;
    NSString *_nation;
    NSString *_passportNumber;
    NSString *_validDate;
    NSString *_usedTime;
    NSDate *start;
    NSString *_verifySecondName;
    NSString *_verifyFirstName;
    AVCaptureDevice *currentDevice;
    
    NSTimeInterval previousTimeInterval;
    NSTimeInterval lastWarningTimeInterval;
    __block dispatch_queue_t queue;
    AVCaptureSession *_captureSession;
    CALayer *_customLayer;
    AVCaptureVideoPreviewLayer *_prevLayer;
    
    UIButton *passportBackButton;
    UIButton *passportInfoButton;
    UIImageView *infoImageView;
    UIButton *infoBackButton;
    UIScrollView *imageScrollView;
    //用来标示，是否已经扫描成功，这样可以防止多次回调
    __block BOOL isScanSuccessful;
}
@property (nonatomic, strong) NSOperationQueue           *operationQueue;
@property (nonatomic, strong) UIImageView                *imageHView;       //扫描线
@property (nonatomic, assign) float                      hightSM;           //扫描线y坐标
@property (nonatomic, strong) NSTimer                    *connectionTimer;  //定时器
@property (nonatomic, retain) AVCaptureSession           *captureSession;
@property (nonatomic, retain) CALayer                    *customLayer;
@property (nonatomic, retain) AVCaptureVideoPreviewLayer *prevLayer;

@end

@implementation SJBPassportScanningViewController

- (id)init {
    self = [super init];
    if (self) {
        self.prevLayer = nil;
        self.customLayer = nil;
        _secondName = nil;
        _firstName = nil;
        _sex = nil;
        _birthDay = nil;
        _nation = nil;
        _passportNumber = nil;
        _validDate = nil;
        _usedTime = nil;
        _verifySecondName = nil;
        _verifyFirstName = nil;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create a queue to perform recognition operations
    self.operationQueue = [[NSOperationQueue alloc] init];
    [self.operationQueue setMaxConcurrentOperationCount:countOfCores()];
    
    
    //用于统计本次扫描所用时间
    start = [NSDate date];
    
    [self initCapture];
    
}



- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    
    [self.captureSession startRunning];
    
}

- (void)configureCamera:(AVCaptureDevice *)device withFrameRate:(int)desiredFrameRate
{
    NSError *error;
    CMTime frameDuration = CMTimeMake(1, desiredFrameRate);
    NSArray *supportedFrameRateRanges = [device.activeFormat videoSupportedFrameRateRanges];
    BOOL frameRateSupported = NO;
    for (AVFrameRateRange *range in supportedFrameRateRanges) {
        if (CMTIME_COMPARE_INLINE(frameDuration, >=, range.minFrameDuration) &&
            CMTIME_COMPARE_INLINE(frameDuration, <=, range.maxFrameDuration)) {
            frameRateSupported = YES;
        }
    }
    
    if (frameRateSupported && [device lockForConfiguration:&error]) {
        [device setActiveVideoMaxFrameDuration:frameDuration];
        [device setActiveVideoMinFrameDuration:frameDuration];
        
        [device unlockForConfiguration];
    }
    
    //设置对调区域，让摄像头自动对焦到机读区
    CGPoint touchPoint = CGPointMake(0.85, 0.5);
    
    if ([device isFocusPointOfInterestSupported]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusPointOfInterest:touchPoint];
            [device setExposurePointOfInterest:touchPoint];
            
            [device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]){
                [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
            [device unlockForConfiguration];
        }
    }

}

-(void)dealloc {
    NSLog(@"First Dealloc");
    [self deleteImageFromDisk:tempPictureName];
    [self.operationQueue cancelAllOperations];
    
    self.customLayer = nil;
    self.prevLayer = nil;
    self.captureSession = nil;
    
    
}

- (void)initCapture {
    
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
    
    currentDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    
    
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:currentDevice error:nil];
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    
    
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    
    
    queue = dispatch_queue_create("cameraQueue", nil);
    
    [captureOutput setSampleBufferDelegate:self queue:queue];
    
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber
                       numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary
                                   dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    
    
    [self.captureSession addInput:captureInput];
    [self.captureSession addOutput:captureOutput];
    
    [self configureCamera:currentDevice withFrameRate:15];
    
    
    [self.captureSession startRunning];
    self.customLayer = [CALayer layer];
    self.customLayer.frame = self.view.bounds;
    self.customLayer.transform = CATransform3DRotate(
                                                     CATransform3DIdentity, M_PI/2.0f, 0, 0, 1);
    self.customLayer.contentsGravity = kCAGravityResizeAspectFill;
    [self.view.layer addSublayer:self.customLayer];
    self.prevLayer = [AVCaptureVideoPreviewLayer
                      layerWithSession: self.captureSession];
    self.prevLayer.frame = CGRectMake(0, DHLGD, VIEWWIDTH, VIEWHIGHT);
    self.prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer: self.prevLayer];
    
    UIImageView *imgaView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, VIEWWIDTH, VIEWHIGHT)];
    imgaView.image = [UIImage imageNamed:self.backGroundImageName];
    [self.view addSubview:imgaView];
    
    _imageHView = [[UIImageView alloc] initWithFrame:CGRectMake(self.scanningFrameRect.origin.x*VIEWWIDTH/IPHONE6WIDTH, self.scanningFrameRect.origin.y*VIEWHIGHT/IPHONE6HEIGHT, self.scanningLineSize.width*VIEWWIDTH/IPHONE6WIDTH, self.scanningLineSize.height*VIEWHIGHT/IPHONE6HEIGHT)];
    
    _imageHView.image = [UIImage imageNamed:self.scanningLineImageName];
    [self.view addSubview:_imageHView];
    
    
    
    _hightSM = 90.0f*VIEWHIGHT/IPHONE6HEIGHT;
    
    _connectionTimer = [NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
    
    [self layoutButtons];
}

- (void) layoutButtons{
    
    passportBackButton = [[UIButton alloc] init];
    [passportBackButton setImage:[UIImage imageNamed: @"passport_back"] forState:UIControlStateNormal];
    [passportBackButton addTarget:self action:@selector(cancelScanning) forControlEvents:UIControlEventTouchUpInside];
    
    passportBackButton.frame = CGRectMake(320.0f, 15.0f, 60.0f, 60.0f);
    [passportBackButton setContentMode:UIViewContentModeScaleAspectFill];
    [self.view addSubview:passportBackButton];
    
    
    
    passportInfoButton = [[UIButton alloc] init];
    [passportInfoButton setImage:[UIImage imageNamed: @"passport_info"] forState:UIControlStateNormal];
    [passportInfoButton addTarget:self action:@selector(showInstruction) forControlEvents:UIControlEventTouchUpInside];
    
    passportInfoButton.frame = CGRectMake(320.0f, 600.0f, 60.0f, 60.0f);
    [passportInfoButton setContentMode:UIViewContentModeScaleAspectFill];
    [self.view addSubview:passportInfoButton];
    
    imageScrollView = [[UIScrollView alloc]initWithFrame:self.view.bounds];
    imageScrollView.bounces = NO;
    
    
    infoImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 505.f*scrennWidthRatio, 667.0f*scrennHeightRatio)];
    infoImageView.contentMode = UIViewContentModeScaleToFill;
    [infoImageView setImage:[UIImage imageNamed:@"passport_example.png"]];
    
    [imageScrollView setContentSize:CGSizeMake(505.f*scrennWidthRatio, 667.f*scrennHeightRatio)];
    [imageScrollView setContentOffset:CGPointMake(imageScrollView.contentSize.width - imageScrollView.bounds.size.width, 0.0f)];
    [imageScrollView addSubview:infoImageView];
    
    
    infoBackButton = [[UIButton alloc] init];
    [infoBackButton setImage:[UIImage imageNamed: @"info_back"] forState:UIControlStateNormal];
    [infoBackButton addTarget:self action:@selector(infoBack) forControlEvents:UIControlEventTouchUpInside];
    
    infoBackButton.frame = CGRectMake(320.0f, 600.0f, 60.0f, 60.0f);
    [infoBackButton setContentMode:UIViewContentModeScaleAspectFit];
    
    infoImageView.userInteractionEnabled = YES;
    
    [self.view addSubview:imageScrollView];
    [self.view addSubview:infoBackButton];
    
    
    imageScrollView.hidden = YES;
    infoBackButton.hidden = YES;
    
    
    
}

- (void)showInstruction{
    
    imageScrollView.hidden = NO;
    infoBackButton.hidden = NO;
    [self.captureSession stopRunning];
    
}

- (void)infoBack{
    
    
    imageScrollView.hidden = YES;
    infoBackButton.hidden = YES;
    [self.captureSession startRunning];
    
    //    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    
}

- (void)cancelScanning{
    [self.operationQueue cancelAllOperations];
    
    [self.connectionTimer invalidate];
    [self.delegate passportScanningCancelled:self];
}

- (UIImage*) imageWithColor:(UIColor*)color size:(CGSize)size
{
    UIGraphicsBeginImageContext(size);
    UIBezierPath* rPath = [UIBezierPath bezierPathWithRect:CGRectMake(0., 0., size.width, size.height)];
    [color setFill];
    [rPath fill];
    UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}


//定时器
-(void)timerFired:(NSTimer *)timer{
    
    if(_hightSM > (self.scanningFrameRect.origin.y + self.scanningFrameRect.size.height - self.scanningLineSize.height - 10) *VIEWHIGHT/IPHONE6HEIGHT){
        _hightSM = self.scanningFrameRect.origin.y*VIEWHIGHT/IPHONE6HEIGHT;
        
    }else{
        _hightSM = _hightSM + 10.0f*VIEWHIGHT/IPHONE6HEIGHT;
    }
    
    
    CGRect imageRect = _imageHView.frame;
    imageRect.origin.y = _hightSM;
    _imageHView.frame = imageRect;
    
}


unsigned int countOfCores() {
    unsigned int ncpu;
    size_t len = sizeof(ncpu);
    sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0);
    return ncpu;
}


- (void)beginOCR:(UIImage *)image
{
    
    @autoreleasepool {
        
        float biliX = image.size.width / IPHONE6WIDTH;
        float biliY = image.size.height / IPHONE6HEIGHT;
        
        CGFloat scaleW = image.size.width / VIEWWIDTH;
        CGRect destRect = CGRectMake(0, 0, image.size.width, VIEWHIGHT*scaleW);
        
        UIImage *newImage;
        UIImageView *tupView;
        @autoreleasepool {
            
            tupView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, destRect.size.width, destRect.size.height)];
            
            tupView.image = image;
            
        }
        
        newImage = nil;
        
        CGRect rect = CGRectMake(self.scanningFrameRect.origin.x *biliX, self.scanningFrameRect.origin.y*biliY, self.scanningFrameRect.size.width*biliX, self.scanningFrameRect.size.height*biliY);
        
        UIImage * finalImage;
        @autoreleasepool {
            
            finalImage = [self captureView:tupView frame:rect];
            
            
            tupView = nil;
            
//            
//            if(YES ==  [self idenfityArrowFromUIImage:finalImage])
//            {
            
                UIImage *oritatedImage = [UIImage imageWithCGImage:finalImage.CGImage scale:1.0f orientation:UIImageOrientationLeft];
                
                finalImage = nil;
                
                
                [self recognizeImageWithTesseract:oritatedImage];
                oritatedImage = nil;
                
                
                
//            }
//            else {
//                finalImage = nil;
//                
//                
//            }
            
        }
        
    }
    
    
    
    image = nil;
    
    
}



- (void)saveImageToPhotos:(UIImage*)savedImage
{
    UIImageWriteToSavedPhotosAlbum(savedImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)image: (UIImage *) image didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo
{
    NSString *msg = nil ;
    if(error != NULL){
        msg = @"保存图片失败" ;
    }else{
        msg = @"保存图片成功" ;
    }
    
    NSLog(@"%@", msg);
    
}


CGRect CGRectCenteredInRect(CGRect rect, CGRect mainRect)
{
    CGFloat xOffset = CGRectGetMidX(mainRect)-CGRectGetMidX(rect);
    CGFloat yOffset = CGRectGetMidY(mainRect)-CGRectGetMidY(rect);
    return CGRectOffset(rect, xOffset, yOffset);
}


// Calculate the destination scale for filling
CGFloat CGAspectScaleFill(CGSize sourceSize, CGRect destRect)
{
    CGSize destSize = destRect.size;
    CGFloat scaleW = destSize.width / sourceSize.width;
    CGFloat scaleH = destSize.height / sourceSize.height;
    return MAX(scaleW, scaleH);
}


CGRect CGRectAspectFillRect(CGSize sourceSize, CGRect destRect)
{
    CGSize destSize = destRect.size;
    CGFloat destScale = CGAspectScaleFill(sourceSize, destRect);
    CGFloat newWidth = sourceSize.width * destScale;
    CGFloat newHeight = sourceSize.height * destScale;
    CGFloat dWidth = ((destSize.width - newWidth) / 2.0f);
    CGFloat dHeight = ((destSize.height - newHeight) / 2.0f);
    CGRect rect = CGRectMake (dWidth, dHeight, newWidth, newHeight);
    return rect;
}



- (UIImage *) applyAspectFillImage: (UIImage *) image InRect: (CGRect) bounds
{
    @autoreleasepool {
        
        
        CGRect destRect;
        
        UIGraphicsBeginImageContext(bounds.size);
        CGRect rect = CGRectAspectFillRect(image.size, bounds);
        destRect = CGRectCenteredInRect(rect, bounds);
        
        [image drawInRect: destRect];
        
        
        
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return newImage;
        
    }
    
}


//
-(UIImage*)captureView:(UIView *)theView frame:(CGRect)fra{
    @autoreleasepool {
        UIGraphicsBeginImageContext(theView.frame.size);
        CGContextRef context = UIGraphicsGetCurrentContext();
        [theView.layer renderInContext:context];
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        CGImage *ref = CGImageCreateWithImageInRect(img.CGImage, fra);
        UIImage *i = [UIImage imageWithCGImage:ref];
        CGImageRelease(ref);
        return i;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    [self.captureSession stopRunning];
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little |
                                                 kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    // Create an image object from the Quartz image
    __autoreleasing UIImage *image = [UIImage imageWithCGImage:quartzImage];
    // Release the Quartz image
    CGImageRelease(quartzImage);
    return (image);
    
}

- (NSString *) applicationDocumentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = paths.firstObject;
    return basePath;
}

- (void)saveImage:(UIImage *)image withName:(NSString *)name {
    NSData *data = UIImagePNGRepresentation(image);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *fullPath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:name];
    [fileManager createFileAtPath:fullPath contents:data attributes:nil];
}

- (void)deleteImageFromDisk:(NSString *)name {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *fullPath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:name];
    [fileManager removeItemAtPath:fullPath error:nil];
}

- (UIImage *)loadImage:(NSString *)name {
    NSString *fullPath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:name];
    UIImage *img = [UIImage imageWithContentsOfFile:fullPath];
    
    return img;
}

#pragma mark -
#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    if (isScanSuccessful)
    {
        return;
    }
    
    @autoreleasepool {
        CFRetain(sampleBuffer);
        
        UIImage * capturedImage;
        
        capturedImage = [self imageFromSampleBuffer:sampleBuffer];
        
        [self saveImage:capturedImage withName:tempPictureName];
        
        CFRelease(sampleBuffer);
        capturedImage = nil;
        
        __block UIImage *restoredImage = [self loadImage:tempPictureName];
        
        restoredImage = [UIImage imageWithCGImage:restoredImage.CGImage scale:1.0 orientation:UIImageOrientationRight];
        
        
        [self beginOCR:restoredImage];
        restoredImage = nil;
    }
    
}

-(void)recognizeImageWithTesseract:(UIImage *)image
{
    //   __block NSDate *methodStart = [NSDate date];
    
    
    
    // Preprocess the image so Tesseract's recognition will be more accurate
    UIImage *bwImage = [image g8_blackAndWhite];
    
    
    // Animate a progress activity indicator
    //    [self.activityIndicator startAnimating];
    
    // Display the preprocessed image to be recognized in the view
    //    self.imageToRecognize.image = bwImage;
    
    // Create a new `G8RecognitionOperation` to perform the OCR asynchronously
    // It is assumed that there is a .traineddata file for the language pack
    // you want Tesseract to use in the "tessdata" folder in the root of the
    // project AND that the "tessdata" folder is a referenced folder and NOT
    // a symbolic group in your project
    //G8RecognitionOperation *operation = [[G8RecognitionOperation alloc] initWithLanguage:@"eng"];
    //G8RecognitionOperation *operation = [[G8RecognitionOperation alloc] initWithLanguage:@"chi_sim"];
    
    G8RecognitionOperation *operation = [[G8RecognitionOperation alloc] initWithLanguage:@"mrz"];
    
    // Use the original Tesseract engine mode in performing the recognition
    // (see G8Constants.h) for other engine mode options
    operation.tesseract.engineMode = G8OCREngineModeTesseractOnly;
    
    // Let Tesseract automatically segment the page into blocks of text
    // based on its analysis (see G8Constants.h) for other page segmentation
    // mode options
    operation.tesseract.pageSegmentationMode = G8PageSegmentationModeAutoOnly;
    
    // Optionally limit the time Tesseract should spend performing the
    // recognition
    //operation.tesseract.maximumRecognitionTime = 1.0;
    
    // Set the delegate for the recognition to be this class
    // (see `progressImageRecognitionForTesseract` and
    // `shouldCancelImageRecognitionForTesseract` methods below)
    operation.delegate = self;
    
    // Optionally limit Tesseract's recognition to the following whitelist
    // and blacklist of characters
    //operation.tesseract.charWhitelist = @"01234";
    //operation.tesseract.charBlacklist = @"56789";
    
    // Set the image on which Tesseract should perform recognition
    operation.tesseract.image = bwImage;
    
    
    
    // Optionally limit the region in the image on which Tesseract should
    // perform recognition to a rectangle
    //operation.tesseract.rect = CGRectMake(20, 20, 100, 100);
    
    __weak SJBPassportScanningViewController *weakSelf = self;
    
    // Specify the function block that should be executed when Tesseract
    // finishes performing recognition on the image
    operation.recognitionCompleteBlock = ^(G8Tesseract *tesseract) {
        // Fetch the recognized text
        NSString *recognizedText = tesseract.recognizedText;
        
        NSLog(@"%@", recognizedText);
        
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            if (isScanSuccessful) {
                return;
            }
            
            // long-running task
            if([weakSelf analysisOCRresult:recognizedText weakSelf:weakSelf])
            {
                //验证成功，结束
                NSLog(@"recongized sucessful");
                
                NSTimeInterval timeInterval = fabs([start timeIntervalSinceNow]);
                _usedTime = [NSString stringWithFormat:@"%d 秒", (int)timeInterval];
                
                [weakSelf.operationQueue cancelAllOperations];
                
                [weakSelf.connectionTimer invalidate];
                
                isScanSuccessful = YES;
                
                [weakSelf.delegate passportScanningSuccessfull:self secondName:_secondName firstName:_firstName sex:_sex birthDay:_birthDay nation:_nation passportNumber:_passportNumber valideDate:_validDate usedTime:_usedTime];
                
                weakSelf.delegate = nil;
                
//                 [weakSelf saveImageToPhotos:bwImage];
                
            } else {
                //验证不成功，继续
                NSLog(@"recongized failed");
                [weakSelf saveImageToPhotos:bwImage];
                
            }
            
            
        });
        
        
        
    };
    
    // Finally, add the recognition operation to the queue
    [weakSelf.operationQueue addOperation:operation];
}

- (BOOL)verifyData: (NSString *)src VerifyCode:(NSString *)code
{
    
    /* 效验步骤
     1. 从左到右，相应顺序位置上的加权数乘相关数字数据要素的每一位数 （加权：不断重复731）
     2. 将每次乘法运算的乘积相加
     3. 将得出对和除以10（模数）
     4. 余数极为效验位
     5. 字幕从A－Z等于10-35
     */
    
    int multiper = 0;
    int dataValue = 0;
    int sum = 0;
    NSRange currentCharacterRange;
    NSString *currentCharacter;
    
    NSCharacterSet *letterCharacters = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    letterCharacters = [letterCharacters invertedSet];
    
    for(int i=0; i < [src length]; i++)
    {
        multiper = ((int)pow((double)2, (double)(2-(i%3)+1)) - 1);
        
        currentCharacterRange = NSMakeRange(i, 1);
        
        currentCharacter = [src substringWithRange:currentCharacterRange];
        
        if ([currentCharacter isEqual:@"<"]) {
            dataValue = 0;
        } else if (NSNotFound == [currentCharacter rangeOfCharacterFromSet:letterCharacters].location) {
            dataValue = (int)[currentCharacter characterAtIndex:0] - 55;
        } else {
            dataValue = (int)[currentCharacter integerValue];
        }
        
        
        sum = sum + dataValue * multiper;
    }
    
    if ([code integerValue] == sum %10) {
        return YES;
    } else {
        NSLog(@"verifyData failed src: %@ code %@", src, code);
        return NO;
    }
}

- (BOOL)analysisOCRresult:(NSString *)mrzText weakSelf:(id)weakSelf
{
    BOOL verifySuccess = YES;
    
    
    //(共有88个字符，每行44个)
    //护照信息分为2行
    mrzText = [mrzText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    mrzText = [mrzText stringByReplacingOccurrencesOfString:@"\\s" withString:@""
                                                    options:NSRegularExpressionSearch
                                                      range:NSMakeRange(0, [mrzText length])];
    mrzText = [mrzText stringByReplacingOccurrencesOfString:@" " withString:@""
                                                    options:NSRegularExpressionSearch
                                                      range:NSMakeRange(0, [mrzText length])];
    
    
    NSLog(@"num: %lu",(unsigned long)mrzText.length);
    
    if(mrzText.length != 88)
    {
        verifySuccess = NO;
        return verifySuccess;
    }
    
    NSCharacterSet *validCharacters = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<"];
    validCharacters = [validCharacters invertedSet];
    
    if (NSNotFound != [mrzText rangeOfCharacterFromSet:validCharacters].location) {
        verifySuccess = NO;
        NSLog(@"illegal characters found!");
        return verifySuccess;
    }
    
    NSRange firstLineRange = NSMakeRange(0, 44);
    NSString *firstLine = [mrzText substringWithRange:firstLineRange];
    
    NSRange secondLineRange = NSMakeRange(44, 44);
    NSString *secondLine = [mrzText substringWithRange:secondLineRange];
    
    //第一行：
    //1－2：po,外国护照不是po，所以把对o的效验去掉
    NSRange passportMarkRange = NSMakeRange(0, 1);
    NSString *passportMark = [firstLine substringWithRange:passportMarkRange];
    
    if(![passportMark isEqual: @"P"])
    {
        verifySuccess = NO;
        return verifySuccess;
    }
    
    //3--5: 签发国或机构（空格用<代替）
    NSRange nationRange = NSMakeRange(2, 3);
    NSString *nation = [firstLine substringWithRange:nationRange];
    _nation = nation;
    
    //6-44:姓名之间用<<风格开，如果只有一个<，则为(空格，“逗号”，“－”），在这里解析为空格（注：如果所有字母之后出现<, 则全部忽略）
    NSRange nameRange = NSMakeRange(5, 39);
    NSString *name = [firstLine substringWithRange:nameRange];
    
    NSCharacterSet *letterCharacters = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ "];
    letterCharacters = [letterCharacters invertedSet];
    
    
    
    NSRange nameSeperatorRange = [name rangeOfString:@"<<"];
    if (nameSeperatorRange.location == NSNotFound) {
        verifySuccess = NO;
        return verifySuccess;
    }
    
    NSRange secondNameRange = NSMakeRange(0, nameSeperatorRange.location);
    NSString *secondName = [name substringWithRange:secondNameRange];
    secondName = [secondName stringByReplacingOccurrencesOfString:@"<" withString:@" "];
    if (NSNotFound != [secondName rangeOfCharacterFromSet:letterCharacters].location) {
        verifySuccess = NO;
        NSLog(@"illegal characters found!");
        return verifySuccess;
    }
    
    _secondName = secondName;
    
    NSRange firstNameRange = NSMakeRange(nameSeperatorRange.location + nameSeperatorRange.length, name.length - secondName.length - 2);
    NSString *firstName = [name substringWithRange:firstNameRange];
    firstName = [firstName stringByReplacingOccurrencesOfString:@"<" withString:@""
                                                        options:NSRegularExpressionSearch
                                                          range:NSMakeRange(0, [firstName length])];
    if (NSNotFound != [firstName rangeOfCharacterFromSet:letterCharacters].location) {
        verifySuccess = NO;
        NSLog(@"illegal characters found!");
        return verifySuccess;
    }
    
    
    _firstName = firstName;
    
    //第二行:
    //1-9:护照号码
    NSRange passportNumberRange = NSMakeRange(0, 9);
    NSString *passportNumber = [secondLine substringWithRange:passportNumberRange];
    _passportNumber = passportNumber;
    
    //10:效验位 （护照号码的效验位）
    
    NSRange passportNumberVerifyRange = NSMakeRange(9, 1);
    NSString *passportNumberVerfy = [secondLine substringWithRange:passportNumberVerifyRange];
    
    if (![weakSelf verifyData:passportNumber VerifyCode:passportNumberVerfy]) {
        verifySuccess = NO;
        return verifySuccess;
    }
    
    
    
    //11-13: 国籍
    NSRange secondNationRange = NSMakeRange(10, 3);
    NSString *secondNation = [secondLine substringWithRange:secondNationRange];
    
    if (![secondNation isEqualToString:nation]) {
        verifySuccess = NO;
        return verifySuccess;
    }
    
    //14-19: 出生日期 YYMMDD
    NSRange birthDayRange = NSMakeRange(13, 6);
    NSString *birthDay = [secondLine substringWithRange:birthDayRange];
    _birthDay = birthDay;
    
    //20:效验位 （出生日期的效验位）
    NSRange birthDayVerifyRange = NSMakeRange(19, 1);
    NSString *birthDayVerify = [secondLine substringWithRange:birthDayVerifyRange];
    
    if (![weakSelf verifyData:birthDay VerifyCode:birthDayVerify]) {
        verifySuccess = NO;
        return verifySuccess;
    }
    
    //21: 性别 F＝女，M＝男，< ＝ 未指明
    NSRange sexRange = NSMakeRange(20, 1);
    NSString *sex = [secondLine substringWithRange:sexRange];
    if(!([sex isEqual:@"M"] || [sex isEqual:@"F"])){
        verifySuccess = NO;
        return verifySuccess;
    }
    
    _sex = sex;
    
    //22-27: 到期日
    NSRange dueDateRange = NSMakeRange(21, 6);
    NSString *dueDate = [secondLine substringWithRange:dueDateRange];
    _validDate = dueDate;
    
    //28: 效验位 （到期日的效验位）
    NSRange dueDateVerifyRange = NSMakeRange(27, 1);
    NSString *dueDateVerify = [secondLine substringWithRange:dueDateVerifyRange];
    
    if (![weakSelf verifyData:dueDate VerifyCode:dueDateVerify]) {
        verifySuccess = NO;
        return verifySuccess;
    }
    
    //29-42: 个人号码
    NSRange personalNumberRange = NSMakeRange(28, 14);
    NSString *personalNumber = [secondLine substringWithRange:personalNumberRange];
    
    //43:效验位 （29-－42用了<的时候，效验位是0或者<)（个人号码效验位）
    NSRange personalNumberVerifyRange = NSMakeRange(42, 1);
    NSString *personalNumberVerify = [secondLine substringWithRange:personalNumberVerifyRange];
    
    //护照上面的信息和规则不符，暂不检测
    
    //    if ([personalNumber rangeOfString:@"<"].location == NSNotFound) {
    //        if (![weakSelf verifyData:personalNumber VerifyCode:personalNumberVerify]) {
    //            verifySuccess = NO;
    //            return verifySuccess;
    //        }
    //
    //    } else {
    //       verifySuccess = ([personalNumberVerify isEqual:@"0"] || [personalNumberVerify isEqual:@"<"]);
    //        if (verifySuccess == NO) {
    //            return verifySuccess;
    //        }
    //    }
    
    
    //44:复合校验位 （1-10， 14-20， 22-43）
    NSRange overallVerifyRange = NSMakeRange(43, 1);
    NSString *overallVerify = [secondLine substringWithRange:overallVerifyRange];
    
    NSString *overallVerifyTarget = [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@", passportNumber, passportNumberVerfy, birthDay, birthDayVerify, dueDate, dueDateVerify, personalNumber, personalNumberVerify];
    
    if (![weakSelf verifyData:overallVerifyTarget VerifyCode:overallVerify]) {
        verifySuccess = NO;
        return verifySuccess;
    }
    
    
    //在这里对两次成功扫描获得的姓名进行验证，只有两次的一样，才认为成功。（因为姓名没有验证码，所以用这种方式提高准确率）
    //
    //    if ((nil == _verifySecondName) || (nil == _verifyFirstName))
    //    {
    //        _verifyFirstName = firstName;
    //        _verifySecondName = secondName;
    //        verifySuccess = NO;
    //         NSLog(@"first time get name");
    //        return verifySuccess;
    //    }
    //
    //    if (!([firstName isEqual:_verifyFirstName] && [secondName isEqual:_verifySecondName])) {
    //        verifySuccess = NO;
    //        NSLog(@"name verified failed _verifyFirstName %@ firstName %@ _verifySecondName %@ secondName %@", _verifyFirstName, firstName, _verifySecondName, secondName);
    //        return verifySuccess;
    //    }
    //
    //
    //    _verifySecondName = nil;
    //    _verifyFirstName = nil;
    
    return verifySuccess;
}




/**
 *  This function is part of Tesseract's delegate. It will be called
 *  periodically as the recognition happens so you can observe the progress.
 *
 *  @param tesseract The `G8Tesseract` object performing the recognition.
 */
- (void)progressImageRecognitionForTesseract:(G8Tesseract *)tesseract {
    //    NSLog(@"progress: %lu", (unsigned long)tesseract.progress);
}

/**
 *  This function is part of Tesseract's delegate. It will be called
 *  periodically as the recognition happens so you can cancel the recogntion
 *  prematurely if necessary.
 *
 *  @param tesseract The `G8Tesseract` object performing the recognition.
 *
 *  @return Whether or not to cancel the recognition.
 */
- (BOOL)shouldCancelImageRecognitionForTesseract:(G8Tesseract *)tesseract {
    return NO;  // return YES, if you need to cancel recognition prematurely
}



#pragma mark -
#pragma mark Memory management
- (void)viewDidUnload {
    self.customLayer = nil;
    self.prevLayer = nil;
    [super viewDidUnload];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace( image.CGImage );
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    cv::Mat cvMat( rows, cols, CV_8UC4 );
    CGContextRef contextRef = CGBitmapContextCreate( cvMat.data, cols, rows, 8, cvMat.step[0], colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault );
    CGContextDrawImage( contextRef, CGRectMake(0, 0, cols, rows), image.CGImage );
    CGColorSpaceRelease( colorSpace );
    CGContextRelease( contextRef );
    return cvMat;
}




- (cv::Mat)grayImage:(cv::Mat) src
{
    cv::Mat grayMat;
    
    cv::cvtColor(src, grayMat, CV_RGB2GRAY);
    
    cv::Mat bw = grayMat > 128;
    
    
    return bw;
}

- (cv::Mat)cannyImage:(cv::Mat) src
{
    // Convert to grayscale
    cv::Mat gray;
    cv::cvtColor(src, gray, CV_BGR2GRAY);
    
    cv::Mat binaryImage = gray > 128;
    
    // Convert to binary image using Canny
    cv::Mat bw;
    cv::Canny(binaryImage, bw, 0, 50, 5);
    
    //    cv::Mat newBW = bw.inv();
    //    cv::Mat newBW = cv::Scalar::all(255) - bw;
    
    std::vector<std::vector<cv::Point>> contours;
    std::vector<cv::Vec4i> hierarchy;
    
    
    
    cv::findContours(bw.clone(), contours,hierarchy, CV_RETR_CCOMP,  CV_CHAIN_APPROX_SIMPLE);
    
    /// Draw contours
    cv::Mat drawing = cv::Mat::zeros( bw.size(), CV_8UC1);
    
    
    std::vector<cv::Point> approx;
    for( int i = 0; i< contours.size(); i++ )
    {
        cv::Scalar colorWhite = cvScalar( 255, 255, 255 );
        cv::Scalar colorBlack = cvScalar( 0, 0, 0 );
        
        
        cv::drawContours( drawing, contours, i, colorWhite, 1, 8, hierarchy, 0, cv::Point());
        
        cv::approxPolyDP(cv::Mat(contours[i]), approx, cv::arcLength(cv::Mat(contours[i]), true) * 0.02, false);
        
        //        if(std::fabs(cv::contourArea(contours[i])) < 2 || !cv::isContourConvex(approx))
        if(std::fabs(cv::contourArea(contours[i])) < 5)
        {
            cv::drawContours( drawing, contours, i, colorBlack, CV_FILLED, 8, hierarchy, 0, cv::Point());
        }
        
    }
    
    return drawing;
}

- (BOOL)idenfityArrowFromUIImage:(UIImage *)image
{
    
    NSDate *methodStart = [NSDate date];
    
    
    cv::Mat cvMat = [self cvMatFromUIImage:image];
    
    cv::Mat binaryImage = [self cannyImage:cvMat];
    
    std::vector<std::vector<cv::Point>> contours;
    std::vector<cv::Vec4i> hierarchy;
    
    cv::findContours(binaryImage.clone(), contours,hierarchy, CV_RETR_TREE,  CV_CHAIN_APPROX_SIMPLE);
    
    //The array for storing the approximation curve
    std::vector<cv::Point> approx;
    int counter = 0;
    
    for (int i = 0; i < contours.size(); i++)
    {
        cv::approxPolyDP(cv::Mat(contours[i]), approx, cv::arcLength(cv::Mat(contours[i]), true) * 0.02, false);
        
        if(std::fabs(cv::contourArea(contours[i])) < 100 )
            continue;
        
        counter ++;
    }
    
    
    
    NSLog(@"count %d", counter);
    
    
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
    NSLog(@"executionTime 2222 = %f", executionTime);
    
    
    if ((counter > 88) && (counter < 210))
    {
        
        return YES;
    } else {
        return NO;
    }
    
}




@end
