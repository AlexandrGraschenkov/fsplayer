//
//  LPProtoProbe.h
//  LinguaPlayer migration prototype (local only, not for the public fork).
//

#import <UIKit/UIKit.h>
#import <FSPlayer/FSPlayer.h>

NS_ASSUME_NONNULL_BEGIN

@interface LPProtoProbe : NSObject

- (instancetype)initWithPlayer:(FSPlayer *)player url:(NSString *)url hostView:(UIView *)hostView;

/// Logs time units, streams, chapters and FFmpeg license/configuration.
- (void)logPrepared;
/// Opens the URL directly through libav* exported from FSPlayer.framework (MediaModule link test).
- (void)runLibavLinkTest;
/// Saves FSSnapshotTypeOrigin, FSSnapshotTypeScreen and drawViewHierarchy images into Documents/proto.
- (void)saveSnapshots;
/// Applies a zoom transform to the render view (clipped by its container).
- (void)applyZoom:(CGFloat)zoom offset:(CGPoint)offset;

@end

NS_ASSUME_NONNULL_END
