//
//  LPProtoProbe.m
//  LinguaPlayer migration prototype (local only, not for the public fork).
//

#import "LPProtoProbe.h"
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswresample/swresample.h>
#include <libavutil/channel_layout.h>

@interface LPProtoProbe ()
@property (nonatomic, weak) FSPlayer *player;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, weak) UIView *hostView;
@end

@implementation LPProtoProbe

- (instancetype)initWithPlayer:(FSPlayer *)player url:(NSString *)url hostView:(UIView *)hostView {
    self = [super init];
    if (self) {
        _player = player;
        _url = [url copy];
        _hostView = hostView;
    }
    return self;
}

- (void)logPrepared {
    FSPlayer *p = self.player;
    NSLog(@"[LPPROTO] license=%s", avcodec_license());
    NSLog(@"[LPPROTO] configuration=%s", avcodec_configuration());
    NSLog(@"[LPPROTO] duration=%.3f currentPlaybackTime=%.3f monitor.duration(ms)=%lld naturalSize=%@",
          p.duration, p.currentPlaybackTime, p.monitor.duration, NSStringFromCGSize(p.naturalSize));
    NSLog(@"[LPPROTO] vdecoder=%@ vcodec=%@ acodec=%@", p.monitor.vdecoder, p.monitor.vcodec, p.monitor.acodec);
    for (NSDictionary *stream in p.monitor.mediaMeta[FS_KEY_STREAMS]) {
        NSLog(@"[LPPROTO] stream idx=%@ type=%@ codec=%@ title=%@ lang=%@",
              stream[FS_KEY_STREAM_IDX], stream[FS_KEY_STREAM_TYPE], stream[FS_KEY_CODEC_NAME],
              stream[FS_KEY_TITLE], stream[FS_KEY_LANGUAGE]);
    }
    NSLog(@"[LPPROTO] selected video=%@ audio=%@ subtitle=%@",
          p.monitor.videoMeta[FS_KEY_STREAM_IDX], p.monitor.audioMeta[FS_KEY_STREAM_IDX], p.monitor.subtitleMeta[FS_KEY_STREAM_IDX]);
    NSLog(@"[LPPROTO] chapters=%@", p.monitor.chapterMetaArr);
}

- (void)runLibavLinkTest {
    NSString *url = self.url;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        AVFormatContext *ctx = NULL;
        int ret = avformat_open_input(&ctx, url.UTF8String, NULL, NULL);
        if (ret < 0) {
            NSLog(@"[LPPROTO] libav open failed: %s", av_err2str(ret));
            return;
        }
        ret = avformat_find_stream_info(ctx, NULL);
        NSLog(@"[LPPROTO] libav streams=%u duration=%.3f find_stream_info=%d",
              ctx->nb_streams, ctx->duration / (double)AV_TIME_BASE, ret);

        AVChannelLayout mono = AV_CHANNEL_LAYOUT_MONO;
        SwrContext *swr = NULL;
        ret = swr_alloc_set_opts2(&swr, &mono, AV_SAMPLE_FMT_S16, 16000,
                                  &mono, AV_SAMPLE_FMT_FLTP, 48000, 0, NULL);
        NSLog(@"[LPPROTO] swr_alloc_set_opts2=%d", ret);
        swr_free(&swr);
        avformat_close_input(&ctx);
    });
}

- (void)saveSnapshots {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                     stringByAppendingPathComponent:@"proto"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *stamp = [NSString stringWithFormat:@"%.2f", self.player.currentPlaybackTime];

    UIView<FSVideoRenderingProtocol> *render = self.player.view;
    [self save:[render snapshot:FSSnapshotTypeOrigin] name:[NSString stringWithFormat:@"%@-origin.png", stamp] dir:dir];
    [self save:[render snapshot:FSSnapshotTypeScreen] name:[NSString stringWithFormat:@"%@-screen.png", stamp] dir:dir];

    UIView *host = self.hostView;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:host.bounds.size];
    UIImage *hierarchy = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [host drawViewHierarchyInRect:host.bounds afterScreenUpdates:NO];
    }];
    [self save:hierarchy.CGImage name:[NSString stringWithFormat:@"%@-hierarchy.png", stamp] dir:dir];
    NSLog(@"[LPPROTO] snapshots saved to %@", dir);
}

- (void)save:(CGImageRef)image name:(NSString *)name dir:(NSString *)dir {
    if (!image) {
        NSLog(@"[LPPROTO] snapshot %@ is NULL", name);
        return;
    }
    NSLog(@"[LPPROTO] snapshot %@ %zux%zu", name, CGImageGetWidth(image), CGImageGetHeight(image));
    NSData *data = UIImagePNGRepresentation([UIImage imageWithCGImage:image]);
    [data writeToFile:[dir stringByAppendingPathComponent:name] atomically:YES];
}

- (void)applyZoom:(CGFloat)zoom offset:(CGPoint)offset {
    self.player.view.transform = CGAffineTransformMake(zoom, 0, 0, zoom, offset.x, offset.y);
}

@end
