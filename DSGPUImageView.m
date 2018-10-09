//
//  DSGPUImageView.m
//  DailyShow
//
//  Created by 朱颖琦 on 2018/8/29.
//  Copyright © 2018年 Kaiyu. All rights reserved.
//

#import "DSGPUImageView.h"
#import "DSFilterInfo.h"
#import "DSGPUImageBeautyFilter.h"
#import "DSFilterHandleTool.h"
#import "UIImage+Clips.h"
#import "DSRecordEngine.h"
#import "DSVIdeoRotationTools.h"

#define kCameraWidth 540.0f
#define kCameraHeight 960.0f
#define RMDefaultVideoPath  [NSString stringWithFormat:@"%@%@.Mov",[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0], [NSString stringWithFormat:@"%ld",(long)[[NSDate date] timeIntervalSince1970]]]


@interface DSGPUImageView()<CAAnimationDelegate>
@property (nonatomic, strong) NSDictionary *audioSettings;
@property (nonatomic, strong) NSMutableDictionary *videoSettings;
@property (nonatomic, strong) GPUImageStillCamera *videoCamera;
@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;
//焦点
@property (nonatomic, strong) CALayer *focusLayer;
/**
 ** 滤镜部分
 */
@property (nonatomic, assign) NSInteger filterSelectIndex;
@property (nonatomic, assign) CGFloat beautyLevel;
@property (nonatomic, assign) CGFloat brightLevel;
@property (nonatomic, strong) GPUImageFilterGroup *normalFilter;
/**
 加速仪 为了实现苹果相机类似旋转图片功能
 */
@property (strong, nonatomic) CMMotionManager *motionManager;
// 图片拍摄方向
@property (nonatomic, assign) UIImageOrientation currentDirection;
//视频第一帧拍摄方向
@property (nonatomic, assign) UIImageOrientation currentMovieDirection;
//旋转视频工具
@property (nonatomic, strong) DSVIdeoRotationTools *rotationTools;
@end

@implementation DSGPUImageView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)]];
        [self setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [self.layer addSublayer:self.focusLayer];
    }
    return self;
}

//初始化 并开启捕获
- (void)initVideoCamera {
//    self.videoCamera.audioEncodingTarget = self.movieWriter;
    self.movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:self.moviePath] size:CGSizeMake(kCameraWidth, kCameraWidth) fileType:AVFileTypeQuickTimeMovie outputSettings:self.videoSettings];
    self.videoCamera.audioEncodingTarget = _movieWriter;

    //创建默认美颜滤镜
    self.normalFilter = [[GPUImageFilterGroup alloc] init];
    //默认美颜 美白
    self.beautyLevel = [DSFilterInfo getBeautyValue];
    self.brightLevel = [DSFilterInfo getBrightValue];
    [self addGPUImageFilter:[[DSGPUImageBeautyFilter alloc] initCustomFilterWithBeautyValue:self.beautyLevel brightValue:self.brightLevel]];
    //默认添加可爱滤镜
    GPUImageOutput<GPUImageInput> *filter = [[DSFilterHandleTool sharedInstance] getFilterWithfilterType:LZBFilterType_Beauty];
    if (filter) [self addGPUImageFilter:filter];
    //默认美颜
    [self.videoCamera addTarget:self.normalFilter];
    [self.normalFilter addTarget:self];
    kDISPATCH_GLOBAL_QUEUE_DEFAULT(^{[self.videoCamera startCameraCapture]; });
}

//移除滤镜效果 停止捕获界面
- (void)removeGPUImageCameraTargets {
    [_normalFilter removeAllTargets];
    [self.videoCamera stopCameraCapture];
    [self.videoCamera removeAllTargets];
    [self.motionManager stopGyroUpdates];
}

// 去除美颜
- (GPUImageFilterGroup *)getDeafultFilter {
    GPUImageFilter *filter = [[GPUImageFilter alloc] init]; //默认
    _normalFilter = [[GPUImageFilterGroup alloc] init];
    [(GPUImageFilterGroup *) _normalFilter setInitialFilters:[NSArray arrayWithObject: filter]];
    [(GPUImageFilterGroup *) _normalFilter setTerminalFilter:filter];
    return _normalFilter;
}

/**
 原理：
 1. filterGroup(addFilter) 滤镜组添加每个滤镜
 2. 按添加顺序（可自行调整）前一个filter(addTarget) 添加后一个filter
 3. filterGroup.initialFilters = @[第一个filter]];
 4. filterGroup.terminalFilter = 最后一个filter;
 */
- (void)addGPUImageFilter:(GPUImageOutput<GPUImageInput> *)filter
{
    [_normalFilter addFilter:filter];
    
    GPUImageOutput<GPUImageInput> *newTerminalFilter = filter;
    
    NSInteger count = _normalFilter.filterCount;
    
    if (count == 1)
    {
        _normalFilter.initialFilters = @[newTerminalFilter];
        _normalFilter.terminalFilter = newTerminalFilter;
        
    } else
    {
        GPUImageOutput<GPUImageInput> *terminalFilter    = _normalFilter.terminalFilter;
        NSArray *initialFilters                          = _normalFilter.initialFilters;
        
        [terminalFilter addTarget:newTerminalFilter];
        
        _normalFilter.initialFilters = @[initialFilters[0]];
        _normalFilter.terminalFilter = newTerminalFilter;
    }
}

#pragma -mark 滤镜
- (void)configBeautyLevel:(CGFloat)beautyLevel {
    self.beautyLevel = beautyLevel/100;
    [self setNormalFilterIndex:self.filterSelectIndex];
}

- (void)configBrightLevel:(CGFloat)brightLevel  {
    self.brightLevel = brightLevel/100;
    [self setNormalFilterIndex:self.filterSelectIndex];
}

- (void)setNormalFilterIndex:(NSInteger)index {
    self.filterSelectIndex = index;
    //组合滤镜
    [self.videoCamera removeAllTargets];
    _normalFilter = [[GPUImageFilterGroup alloc] init];
    //    if (self.beautyLevel == 0 && self.brightLevel == 0) {//无美颜效果
    //        _normalFilter =  [self getDeafultFilter];
    //    }else {
    DSGPUImageBeautyFilter *leveBeautyFilter = [[DSGPUImageBeautyFilter alloc] initCustomFilterWithBeautyValue:self.beautyLevel brightValue:self.brightLevel];
    [self addGPUImageFilter:leveBeautyFilter];
    //    }
    GPUImageOutput<GPUImageInput> *filter = [[DSFilterHandleTool sharedInstance] getFilterWithfilterType:index];
    if (filter) [self addGPUImageFilter:filter];
    [self.videoCamera addTarget:self.normalFilter];
    [self.normalFilter addTarget:self];
}

- (void)saveFilter {
    [DSFilterInfo saveFilterBrightValue:self.brightLevel beautyValue:self.beautyLevel];
}

//开启加速仪(方向检测)
- (void)startDeviceMotion {
    if (![self.motionManager isDeviceMotionAvailable]) {return;}
    [self.motionManager setDeviceMotionUpdateInterval:1.f];
    [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        //Gravity 获取手机的重力值在各个方向上的分量
        double x = motion.gravity.x;
        double y = motion.gravity.y;
        double z = motion.gravity.z;
        self.currentDirection = UIImageOrientationUp;
        if (fabs(z) < 0.5) {
            if (fabs(y)>=fabs(x)) {
                if (y >= 0) self.currentDirection = UIImageOrientationDown;
            }
            else {
                if (x >= 0) self.currentDirection = UIImageOrientationRight;
                else self.currentDirection = UIImageOrientationLeft;
            }
        }
    }];
}

//翻转摄像头
- (void)inputSideBtnHandler {
    [self.videoCamera pauseCameraCapture];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.videoCamera rotateCamera];
        [self.videoCamera resumeCameraCapture];
    });
}

//拍照
- (void)takePhotoHandler:(void(^)(UIImage *image,NSError *error))handler {
    [self.videoCamera capturePhotoAsImageProcessedUpToFilter:self.normalFilter  withCompletionHandler:^(UIImage *processedImage, NSError *error) {
        __block UIImage *image = processedImage;
        [self createNewWritter];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image) {
                if (handler) handler(nil, error);return;
            }
            if (!iPhoneX) {
                image = [image rotate:self.currentDirection];
            }
            if (handler) handler(image, error);
        });
    }];
}

- (void)createNewWritter {
//    /// 如果不加上这一句，会出现第一帧闪现黑屏
//    [self.videoCamera addAudioInputsAndOutputs];
//    self.videoCamera.audioEncodingTarget = self.movieWriter;
    self.movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:self.moviePath] size:CGSizeMake(kCameraWidth, kCameraWidth) fileType:AVFileTypeQuickTimeMovie outputSettings:self.videoSettings];
    /// 如果不加上这一句，会出现第一帧闪现黑屏
    [_videoCamera addAudioInputsAndOutputs];
    _videoCamera.audioEncodingTarget = _movieWriter;
}

//开始视频录制
- (void)recordStartHandler {
    //设定视频录制方向
    self.currentMovieDirection = self.currentDirection;
    // 如果已经存在文件，AVAssetWriter会有异常，删除旧文件
    unlink([self.moviePath UTF8String]);
    //滤镜加到writer
    [self.normalFilter addTarget:self.movieWriter];
    //开始录制
    [self.movieWriter startRecording];
}

//结束视频录制
- (void)recordFinishHandler:(void(^)(UIImage *firstVideoImage))handler {
    //移除target
    [self.normalFilter removeTarget:self.movieWriter];
    @weakify(self);
    [self.movieWriter finishRecordingWithCompletionHandler:^{
        @strongify(self);
        [self createNewWritter];
        //获取视频第一帧
        [DSRecordEngine getFirstMovieImageWithvideoPath:self.moviePath handler:^(UIImage *movieImage) {
            if (!movieImage) return ;
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage * image = [movieImage rotate:self.currentMovieDirection];
                if (handler) handler(image);
            });
        }];
    }];
}

- (void)videoRotationHandler:(void(^)(NSString *desPath, NSString *moviePath))handler {
    WS(weakSelf);
    self.rotationTools.block = ^(NSString *desPath) {
        kDISPATCH_MAIN_THREAD(^{
            //完成旋转 重置方向 
            weakSelf.currentMovieDirection = UIImageOrientationUp;
            if (handler) handler(desPath,weakSelf.moviePath);
        });
    } ;
    [self.rotationTools rotateVideoAssetWithFilePath:self.moviePath recordDiection:self.currentMovieDirection];
}


#pragma -mark 聚焦
- (void)tapAction:(UITapGestureRecognizer *)tap {
    if (self.hideBeautyContainerAction) {
        self.hideBeautyContainerAction();
    }
    [self focusTap:tap];
}

// 聚焦操作
- (void)focusTap:(UITapGestureRecognizer *)tap {
    //    self.cameraView.userInteractionEnabled = NO;
    CGPoint touchPoint = [tap locationInView:tap.view];
    [self layerAnimationWithPoint:touchPoint];
    touchPoint = CGPointMake(touchPoint.x / tap.view.bounds.size.width, touchPoint.y / tap.view.bounds.size.height);
    /*以下是相机的聚焦和曝光设置，前置不支持聚焦但是可以曝光处理，后置相机两者都支持，下面的方法是通过点击一个点同时设置聚焦和曝光，当然根据需要也可以分开进行处理
     */
    if ([self.videoCamera.inputCamera isExposurePointOfInterestSupported] && [self.videoCamera.inputCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        NSError *error;
        if ([self.videoCamera.inputCamera lockForConfiguration:&error]) {
            
            [self.videoCamera.inputCamera setExposurePointOfInterest:touchPoint];
            [self.videoCamera.inputCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            if([self.videoCamera.inputCamera isFocusPointOfInterestSupported] && [self.videoCamera.inputCamera isFocusModeSupported:AVCaptureFocusModeAutoFocus])
            {
                [self.videoCamera.inputCamera setFocusPointOfInterest:touchPoint];
                [self.videoCamera.inputCamera setFocusMode:AVCaptureFocusModeAutoFocus];
            }
            
            [self.videoCamera.inputCamera unlockForConfiguration];
            
        } else {
            NSLog(@"ERROR = %@", error);
        }
    }
}

// 焦点动画
- (void)layerAnimationWithPoint:(CGPoint)point {
    if (_focusLayer) {
        CALayer *focusLayer = _focusLayer;
        focusLayer.hidden = NO;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [focusLayer setPosition:point];
        focusLayer.transform = CATransform3DMakeScale(2.0f,2.0f,1.0f);
        [CATransaction commit];
        
        CABasicAnimation *animation = [ CABasicAnimation animationWithKeyPath: @"transform" ];
        animation.toValue = [ NSValue valueWithCATransform3D: CATransform3DMakeScale(1.0f,1.0f,1.0f)];
        animation.delegate = self;
        animation.duration = 0.3f;
        animation.repeatCount = 1;
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeForwards;
        [focusLayer addAnimation: animation forKey:@"animation"];
    }
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    [self performSelector:@selector(focusLayerNormal) withObject:self afterDelay:1.0f];
}

- (void)focusLayerNormal {
    self.userInteractionEnabled = YES;
    _focusLayer.hidden = YES;
}

- (BOOL)isUpDirection {
    return self.currentMovieDirection == UIImageOrientationUp;
}

#pragma mark - Property
- (GPUImageStillCamera *)videoCamera {
    if (!_videoCamera) {
        _videoCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionFront];
        _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
        _videoCamera.horizontallyMirrorFrontFacingCamera = YES;//currentCaptureMetadata
        [_videoCamera addAudioInputsAndOutputs];//该句可防止允许声音通过的情况下，避免录制第一帧黑屏闪屏
    }
    return _videoCamera;
}
- (NSDictionary *)audioSettings {
    if (!_audioSettings) {
        // 音频设置
        AudioChannelLayout channelLayout;
        memset(&channelLayout, 0, sizeof(AudioChannelLayout));
        channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
        _audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                          [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                          [ NSNumber numberWithInt: 2 ], AVNumberOfChannelsKey,
                          [ NSNumber numberWithFloat: 16000.0 ], AVSampleRateKey,
                          [ NSData dataWithBytes:&channelLayout length: sizeof( AudioChannelLayout ) ], AVChannelLayoutKey,
                          [ NSNumber numberWithInt: 32000 ], AVEncoderBitRateKey,
                          nil];
    }
    return _audioSettings;
}

- (NSMutableDictionary *)videoSettings {
    if (!_videoSettings) {
        _videoSettings = [[NSMutableDictionary alloc] init];
        [_videoSettings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];
        [_videoSettings setObject:[NSNumber numberWithInteger:kCameraWidth] forKey:AVVideoWidthKey];
        [_videoSettings setObject:[NSNumber numberWithInteger:kCameraHeight] forKey:AVVideoHeightKey];
    }
    return _videoSettings;
}

- (CALayer *)focusLayer {
    if (!_focusLayer) {
        UIImage *focusImage = [UIImage imageNamed:@"touch_focus_x"];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, focusImage.size.width, focusImage.size.height)];
        imageView.image = focusImage;
        _focusLayer = imageView.layer;
        _focusLayer.hidden = YES;
    }
    return _focusLayer;
}

- (NSString *)moviePath {
    if (!_moviePath) {
        _moviePath = RMDefaultVideoPath;
    }
    return _moviePath;
}

//- (GPUImageMovieWriter *)movieWriter {
//    if (!_movieWriter) {
//        _movieWriter =  [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:self.moviePath] size:CGSizeMake(kCameraWidth, kCameraWidth) fileType:AVFileTypeQuickTimeMovie outputSettings:self.videoSettings];
//    }
//    return _movieWriter;
//}

- (CMMotionManager *)motionManager {
    if (_motionManager == nil) {
        _motionManager = [[CMMotionManager alloc] init];
    }
    return _motionManager;
}

- (DSVIdeoRotationTools *)rotationTools {
    if (!_rotationTools) {
        _rotationTools = [[DSVIdeoRotationTools alloc] init];
    }
    return _rotationTools;
}


@end
