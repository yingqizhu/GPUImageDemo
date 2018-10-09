//
//  DSGPUImageView.h
//  DailyShow
//
//  Created by 朱颖琦 on 2018/8/29.
//  Copyright © 2018年 Kaiyu. All rights reserved.
//

#import <GPUImage/GPUImage.h>

@interface DSGPUImageView : GPUImageView

@property (nonatomic, copy) EmptyParamBlock hideBeautyContainerAction;
@property (nonatomic, copy) NSString *moviePath;

//初始化所有组件  并开启捕获
- (void)initVideoCamera;
//移除滤镜效果 停止捕获界面 通知陀螺仪
- (void)removeGPUImageCameraTargets;
//开启加速仪(陀螺仪)
- (void)startDeviceMotion;
//翻转摄像头
- (void)inputSideBtnHandler;
//拍照
- (void)takePhotoHandler:(void(^)(UIImage *image,NSError *error))handler;
//开始视频录制
- (void)recordStartHandler;
//结束视频录制
- (void)recordFinishHandler:(void(^)(UIImage *firstVideoImage))handler;
//视频旋转处理
- (void)videoRotationHandler:(void(^)(NSString *desPath, NSString *moviePath))handler;
//美颜
- (void)configBeautyLevel:(CGFloat)beautyLevel;
//美白
- (void)configBrightLevel:(CGFloat)brightLevel;
//滤镜
- (void)setNormalFilterIndex:(NSInteger)index;
//保存滤镜的值
- (void)saveFilter;
//是否竖直方向拍摄
- (BOOL)isUpDirection;

@end
