#import <UIKit/UIKit.h>

@interface ScannerOverlay : UIView
  @property(nonatomic) CGRect scanLineRect;
  @property(nonatomic) CGRect scanRect;
  
  - (void) startAnimating;
  - (void) stopAnimating;
@end
