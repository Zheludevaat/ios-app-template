#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface RootViewController : UIViewController <WKNavigationDelegate, WKUIDelegate>
@property (strong, nonatomic) WKWebView *webView;
@end
