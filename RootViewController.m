#import "RootViewController.h"

// Change this to your server URL before building.
// For local dev on same WiFi: http://<YOUR_PC_IP>:3003
// For production: your hosted HTTPS URL
static NSString *const kDefaultURL = @"http://192.168.99.119:3003/app";
static NSString *const kURLUserDefaultsKey = @"aloud_server_url";

@implementation RootViewController {
    UIActivityIndicatorView *_spinner;
    UILabel *_statusLabel;
    UIButton *_retryButton;
    NSString *_currentURL;
    BOOL _hasError;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    // Read URL from UserDefaults, fall back to default
    NSString *savedURL = [[NSUserDefaults standardUserDefaults] stringForKey:kURLUserDefaultsKey];
    _currentURL = (savedURL.length > 0) ? savedURL : kDefaultURL;

    // WKWebView configuration
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    // JavaScript is enabled by default; allow persistent storage via preferences
    WKPreferences *prefs = [[WKPreferences alloc] init];
    config.preferences = prefs;

    // WKWebView compat: replace webpack's script-src chunk loader with fetch+inline.
    // WKWebView on iOS 16 can fail to execute dynamically created <script src> tags.
    // This intercepts __webpack_require__.l before any chunks load and swaps in a
    // fetch()-based loader that injects chunk code via inline <script> elements.
    // JS errors are also forwarded to the native error screen.
    NSString *compatScript = @"\
(function(){\
  var realDefineProperty=Object.defineProperty;\
  var scriptSrcDesc=Object.getOwnPropertyDescriptor(HTMLScriptElement.prototype,'src');\
  var origSrcSet=scriptSrcDesc.set;\
  scriptSrcDesc.set=function(url){\
    origSrcSet.call(this,url);\
    if(!url||!url.includes('/_next/static/chunks/'))return;\
    var el=this;\
    var retries=0;\
    el.addEventListener('error',function onErr(){\
      if(++retries>3)return;\
      var s=document.createElement('script');\
      s.src=url;\
      if(el.crossOrigin)s.crossOrigin=el.crossOrigin;\
      s.addEventListener('error',onErr);\
      s.onload=el.onload;\
      document.head.appendChild(s);\
    });\
  };\
  Object.defineProperty(HTMLScriptElement.prototype,'src',scriptSrcDesc);\
  window.addEventListener('error',function(e){\
    if(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.error){\
      window.webkit.messageHandlers.error.postMessage(e.message+'\\n'+e.filename+' :'+e.lineno+':'+e.colno);\
    }\
    return false;\
  });\
  window.addEventListener('unhandledrejection',function(e){\
    if(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.error){\
      window.webkit.messageHandlers.error.postMessage('Promise: '+String(e.reason));\
    }\
  });\
})();";
    WKUserScript *compatUserScript = [[WKUserScript alloc]
        initWithSource:compatScript
        injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:NO];
    [config.userContentController addUserScript:compatUserScript];
    [config.userContentController addScriptMessageHandler:self name:@"error"];

    // Create WebView
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    self.webView.backgroundColor = [UIColor blackColor];
    self.webView.opaque = NO;
    self.webView.allowsBackForwardNavigationGestures = NO;
    [self.view addSubview:self.webView];

    // Full-screen constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.webView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    // Loading spinner
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.color = [UIColor whiteColor];
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];
    [NSLayoutConstraint activateConstraints:@[
        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];

    // Status label (shown on error)
    _statusLabel = [[UILabel alloc] init];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.textColor = [UIColor lightGrayColor];
    _statusLabel.font = [UIFont systemFontOfSize:14];
    _statusLabel.numberOfLines = 0;
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.hidden = YES;
    [self.view addSubview:_statusLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_statusLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
    ]];

    // Retry button (shown on error)
    _retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_retryButton setTitle:@"Retry" forState:UIControlStateNormal];
    _retryButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_retryButton addTarget:self action:@selector(loadApp) forControlEvents:UIControlEventTouchUpInside];
    _retryButton.hidden = YES;
    [self.view addSubview:_retryButton];
    [NSLayoutConstraint activateConstraints:@[
        [_retryButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_retryButton.topAnchor constraintEqualToAnchor:_statusLabel.bottomAnchor constant:20],
    ]];

    [self loadApp];
}

- (void)loadApp {
    _hasError = NO;
    [_spinner startAnimating];
    _statusLabel.hidden = YES;
    _retryButton.hidden = YES;
    self.webView.hidden = NO;

    NSURL *url = [NSURL URLWithString:_currentURL];
    if (!url) {
        [self showError:[NSString stringWithFormat:@"Invalid URL: %@", _currentURL]];
        return;
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:15.0];
    [self.webView loadRequest:request];
}

- (void)showError:(NSString *)message {
    _hasError = YES;
    [_spinner stopAnimating];
    self.webView.hidden = YES;
    _statusLabel.text = message;
    _statusLabel.hidden = NO;
    _retryButton.hidden = NO;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (_hasError) return;
    [_spinner stopAnimating];
    _statusLabel.hidden = YES;
    _retryButton.hidden = YES;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) return; // Ignore cancellations
    [self showError:[NSString stringWithFormat:@"Could not connect to:\n%@\n\n%@\n\nMake sure the server is running and your phone is on the same WiFi network.", _currentURL, error.localizedDescription]];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) return;
    [self showError:[NSString stringWithFormat:@"Could not reach:\n%@\n\n%@\n\nCheck that:\n• The server is running\n• Your phone and PC are on the same WiFi\n• The IP address is correct", _currentURL, error.localizedDescription]];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    // Open external links in Safari
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        NSURL *url = navigationAction.request.URL;
        if (![url.host isEqualToString:[[NSURL URLWithString:_currentURL] host]]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - WKUIDelegate

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler();
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completionHandler(NO);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"error"]) {
        NSLog(@"WKWebView JS error: %@", message.body);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showError:[NSString stringWithFormat:@"JS Error:\n%@\n\nURL: %@", message.body, _currentURL]];
        });
    }
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

@end
