#import "OpenglTexturePlugin.h"
#import "OpenGLRender.h"
#import "SampleRenderWorker.h"

@interface OpenglTexturePlugin()
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, OpenGLRender *> *renders;
@property (nonatomic, strong) NSObject<FlutterTextureRegistry> *textures;

@property (strong, nonatomic) NSObject<FlutterPluginRegistrar>* registrar;
@end

@implementation OpenglTexturePlugin

- (instancetype)initWithTextures:(NSObject<FlutterTextureRegistry> *)textures {
    self = [super init];
    if (self) {
        _renders = [[NSMutableDictionary alloc] init];
        _textures = textures;
    }
    return self;
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"opengl_texture"
                                     binaryMessenger:[registrar messenger]];
    OpenglTexturePlugin* instance = [[OpenglTexturePlugin alloc] initWithTextures:[registrar textures]];
    [registrar addMethodCallDelegate:instance channel:channel];
    instance.registrar = registrar;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"create" isEqualToString:call.method]) {
        CGFloat width = [call.arguments[@"width"] floatValue];
        CGFloat height = [call.arguments[@"height"] floatValue];
        
        NSInteger __block textureId;
        id<FlutterTextureRegistry> __weak registry = self.textures;
        
        OpenGLRender *render = [[OpenGLRender alloc] initWithSize:CGSizeMake(width, height)
                                                           worker:[[SampleRenderWorker alloc] init]
                                                       onNewFrame:^{
                                                           [registry textureFrameAvailable:textureId];
                                                       }];
        
        textureId = [self.textures registerTexture:render];
        render.registrar = self.registrar;
        self.renders[@(textureId)] = render;
        NSLog(@"textureid");
        result(@(textureId));
    } else if ([@"dispose" isEqualToString:call.method]) {
        NSNumber *textureId = call.arguments[@"textureId"];
        OpenGLRender *render = self.renders[textureId];
        [render dispose];
        [self.renders removeObjectForKey:textureId];
        result(nil);
    } else if ([@"loadData" isEqualToString:call.method]) {
        NSLog(@"load data");
        NSNumber *textureId = call.arguments[@"textureId"];
        OpenGLRender *render = self.renders[textureId];
        [render.registrar.textures textureFrameAvailable:textureId.integerValue];
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}

@end
