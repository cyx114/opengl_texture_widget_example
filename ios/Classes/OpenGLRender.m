//
//  OpenGLRender.m
//  opengl_texture
//
//  Created by German Saprykin on 22/4/18.
//

#import "OpenGLRender.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface OpenGLRender()
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) id<OpenGLRenderWorker> worker;
@property (copy, nonatomic) void(^onNewFrame)(void);

@property (nonatomic) GLuint frameBuffer;
@property (nonatomic) GLuint depthBuffer;
@property (nonatomic) CVPixelBufferRef target;
@property (nonatomic) CVOpenGLESTextureCacheRef textureCache;
@property (nonatomic) CVOpenGLESTextureRef texture;
@property (nonatomic) CGSize renderSize;
@property (nonatomic) BOOL running;
@end

@implementation OpenGLRender

- (instancetype)initWithSize:(CGSize)renderSize
                      worker:(id<OpenGLRenderWorker>)worker
                  onNewFrame:(void(^)(void))onNewFrame {
    self = [super init];
    if (self){
        self.renderSize = renderSize;
        self.running = YES;
        self.onNewFrame = onNewFrame;
        self.worker = worker;
        
        NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(run) object:nil];
        thread.name = @"OpenGLRender";
        [thread start];
    }
    return self;
}

- (void)run {
    [self initGL];
    [_worker onCreate];
    
    while (_running) {
        CFTimeInterval loopStart = CACurrentMediaTime();
        
        if ([_worker onDraw]) {
            glFlush();
            dispatch_async(dispatch_get_main_queue(), self.onNewFrame);
        }
        
        CFTimeInterval waitDelta = 0.016 - (CACurrentMediaTime() - loopStart);
        if (waitDelta > 0) {
            [NSThread sleepForTimeInterval:waitDelta];
        }
    }
    [_worker onDispose];
    [self deinitGL];
}

#pragma mark - Public

- (void)dispose {
    _running = NO;
}

#pragma mark - FlutterTexture

- (CVPixelBufferRef)copyPixelBuffer {
//    CVBufferRetain(_target);
//    return _target;
    return [self getYUVData];
}

- (CVPixelBufferRef)getYUVData {
    NSString* key = [self.registrar lookupKeyForAsset:@"assets/test.yuv"];
    NSString* path = [[NSBundle mainBundle] pathForResource:key ofType:nil];
    NSLog(@"assetPath:%@", path);
    NSData *data = [NSData dataWithContentsOfFile:path];
    void *buffer = (void *)data.bytes;
    void *srcY = buffer;
    void *srcU = buffer + 1280 * 720;
    void *srcV = buffer + 1280 * 720 * 5/4;
    return [self i420ToPixelBuffer:srcY srcU:srcU srcV:srcV width:1280 height:720];
}

- (CVPixelBufferRef)i420ToPixelBuffer:(void *)srcY srcU:(void *)srcU srcV:(void *)srcV width:(int)width height:(int)height {
    int size = width * height * 3 / 2;
    int yLength = width * height;
    int uLength = yLength / 4;
    if (srcY == NULL) {
        return nil;
    }
    unsigned char *buf = (unsigned char *)malloc(size);
    memcpy(buf, srcY, yLength);
    memcpy(buf + yLength, srcU, uLength);
    memcpy(buf + yLength + uLength, srcV, uLength);
    
    unsigned char * NV12buf = (unsigned char *)malloc(size);
    [self yuv420p_to_nv12:buf nv12:NV12buf width:width height:height];
    
    free(buf);
    
    int w = width;
    int h = height;
    NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          w,
                                          h,
                                          kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                          (__bridge CFDictionaryRef)(pixelAttributes),
                                          &pixelBuffer);
    if (result != kCVReturnSuccess) {
        NSLog(@"Unable to create cvpixelbuffer %d", result);
        free(NV12buf);
        return  nil;
    }

    CVPixelBufferLockBaseAddress(pixelBuffer,0);
    void *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    // Here y_ch0 is Y-Plane of YUV(NV12) data.
    unsigned char *y_ch0 = NV12buf;
    unsigned char *y_ch1 = NV12buf + w * h;
    memcpy(yDestPlane, y_ch0, w * h);
    void *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);

    // Here y_ch1 is UV-Plane of YUV(NV12) data.
    memcpy(uvDestPlane, y_ch1, w * h * 0.5);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    free(NV12buf);
    return pixelBuffer;
}


- (void)yuv420p_to_nv12:(unsigned char*)yuv420p nv12:(unsigned char*)nv12 width:(int)width height:(int)height {
    int i, j;
    int y_size = width * height;
    
    unsigned char* y = yuv420p;
    unsigned char* u = yuv420p + y_size;
    unsigned char* v = yuv420p + y_size * 5 / 4;
    
    unsigned char* y_tmp = nv12;
    unsigned char* uv_tmp = nv12 + y_size;
    
    memcpy(y_tmp, y, y_size);
    
    for (j = 0, i = 0; j < y_size * 0.5; j += 2, i++) {
        uv_tmp[j] = u[i];
        uv_tmp[j+1] = v[i];
    }
}

#pragma mark - Private

- (void)initGL {
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    [EAGLContext setCurrentContext:_context];
    [self createCVBufferWithSize:_renderSize withRenderTarget:&_target withTextureOut:&_texture];
    
    glBindTexture(CVOpenGLESTextureGetTarget(_texture), CVOpenGLESTextureGetName(_texture));
    
    glTexImage2D(GL_TEXTURE_2D,
                 0, GL_RGBA,
                 _renderSize.width, _renderSize.height,
                 0, GL_RGBA,
                 GL_UNSIGNED_BYTE, NULL);
    
    glGenRenderbuffers(1, &_depthBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, _renderSize.width, _renderSize.height);
    
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(_texture), 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthBuffer);
    
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
}

- (void)createCVBufferWithSize:(CGSize)size
              withRenderTarget:(CVPixelBufferRef *)target
                withTextureOut:(CVOpenGLESTextureRef *)texture {
    
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
    
    if (err) return;
    
    CFDictionaryRef empty;
    CFMutableDictionaryRef attrs;
    empty = CFDictionaryCreate(kCFAllocatorDefault,
                               NULL,
                               NULL,
                               0,
                               &kCFTypeDictionaryKeyCallBacks,
                               &kCFTypeDictionaryValueCallBacks);
    
    attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1,
                                      &kCFTypeDictionaryKeyCallBacks,
                                      &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
    CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height,
                        kCVPixelFormatType_32BGRA, attrs, target);
    
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                 _textureCache,
                                                 *target,
                                                 NULL, // texture attributes
                                                 GL_TEXTURE_2D,
                                                 GL_RGBA, // opengl format
                                                 size.width,
                                                 size.height,
                                                 GL_BGRA, // native iOS format
                                                 GL_UNSIGNED_BYTE,
                                                 0,
                                                 texture);
    
    CFRelease(empty);
    CFRelease(attrs);
}

- (void)deinitGL {
    glDeleteFramebuffers(1, &_frameBuffer);
    glDeleteFramebuffers(1, &_depthBuffer);
    CFRelease(_target);
    CFRelease(_textureCache);
    CFRelease(_texture);
}

@end
