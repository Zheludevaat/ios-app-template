# How to Build Your Own iPhone Apps (Without a Mac)

## What Is This?

This folder contains everything you need to build an iPhone app on your Windows PC and install it on your jailbroken iPhone. Every time you make a change and push it to GitHub, a free cloud Mac compiles your code and gives you back an installable app file (an "IPA"). You then copy it to your phone and install it.

You don't need a Mac. You don't need to pay Apple $99/year. You don't need to deal with code signing, certificates, provisioning profiles, or app expiration. The jailbreak handles all of that.

## Why This Works (The "One Weird Trick")

Apple normally requires every app to be digitally signed — like a wax seal proving Apple approved it. This is why you can't just install any app on a stock iPhone.

Your jailbroken phone has a component called **AppSync Unified**. Think of it as removing the lock on the front door. AppSync tells iOS: "Don't bother checking signatures. Just install whatever I give you." This means you can build completely unsigned apps — no Apple involvement at all — and they install and run permanently. No 7-day expiry. No revokes.

The one piece you still need is the compilation step (turning human-written code into a binary the iPhone's processor understands). This requires Apple's compiler, which only runs on macOS. The solution: GitHub Actions, which gives you free access to cloud Macs that do the compilation for you.

## What's in This Folder

| File | What it does |
|------|-------------|
| `Makefile` | Tells the compiler how to build your app (which files, which frameworks, minimum iOS version) |
| `control` | App metadata — name, version, bundle ID |
| `main.m` | The starting point of any iOS app. You won't usually touch this. |
| `AppDelegate.h` / `AppDelegate.m` | Sets up the app window when it launches |
| `RootViewController.h` / `RootViewController.m` | The actual screen content. **This is where you'll write your UI.** |
| `Resources/Info.plist` | App configuration — name, icon settings, supported orientations |
| `.github/workflows/build.yml` | The recipe that tells GitHub's cloud Mac how to compile your app |

## What You Need Before Starting

1. **A jailbroken iPhone** with these installed from Cydia/Sileo/Zebra:
   - **OpenSSH** — lets your PC talk to the phone (usually pre-installed on most jailbreaks)
   - **AppSync Unified** — from repo `https://cydia.akemi.ai/`
   - **appinst** — from repo `https://lukezgd.github.io/repo`
2. **A GitHub account** (free — sign up at github.com)
3. **Git** installed on your PC (download from git-scm.com)
4. **An SCP client** to transfer files to your phone. On Windows, you can use:
   - The `scp` command built into PowerShell (easiest)
   - WinSCP (graphical, if you prefer clicking to typing)

## Step-by-Step: Zero to App on Phone

### Step 1: Put This Project on GitHub

1. Go to github.com, click the "+" in the top right, choose "New repository"
2. Name it whatever you want (e.g., `my-ios-app`). Set it to **Public** (free builds) or Private (limited free minutes). Click "Create repository"
3. GitHub will show you a page of commands. In PowerShell on your PC, navigate to this folder and run:

```powershell
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO-NAME.git
git push -u origin main
```

### Step 2: Watch It Build

1. Go to your repo on GitHub
2. Click the **Actions** tab at the top
3. You should see a workflow running (or already finished) called "Build unsigned IPA"
4. Click into it. You'll see the steps running: "Install Theos", "Build app", "Create unsigned IPA"
5. When it finishes (2-5 minutes), scroll down to **Artifacts**. You'll see `MyApp-unsigned`. Click to download it.
6. You now have a file called `MyApp.ipa`. This is your app.

### Step 3: Install on Your iPhone

1. Make sure your iPhone and PC are on the same Wi-Fi network
2. On your iPhone, go to Settings → Wi-Fi → tap the connected network → note the IP address (something like `192.168.1.5`)
3. In PowerShell on your PC:

```powershell
# Copy the IPA to your phone (default SSH password is "alpine")
scp MyApp.ipa root@192.168.1.5:/var/mobile/Documents/
```

4. Then SSH into your phone:

```powershell
ssh root@192.168.1.5
```

(Password is `alpine` unless you changed it)

5. Once you're in (you'll see a `#` prompt), install the app:

```bash
appinst /var/mobile/Documents/MyApp.ipa
```

6. The app appears on your home screen immediately (if not, run `killall SpringBoard` to refresh).

### Step 4: Make It Your Own

Open `RootViewController.m` in any text editor. The `viewDidLoad` method is where the screen content is set up. The current version just shows a centered label with "Built without a Mac!"

To change the text, find this line:

```objc
label.text = @"Built without a Mac!";
```

Change it to whatever you want:

```objc
label.text = @"My Awesome App";
```

To change the background color, find:

```objc
self.view.backgroundColor = [UIColor systemBackgroundColor];
```

Change it to:

```objc
self.view.backgroundColor = [UIColor blueColor];  // or redColor, greenColor, etc.
```

When you're done, save, commit, and push:

```powershell
git add .
git commit -m "Changed the text and color"
git push
```

GitHub will automatically build a new IPA. Go back to the Actions tab, download the new artifact, and install it over the old one (same SCP + appinst commands). The old version gets replaced.

## How to Add More UI Elements

### Add a Button

In `RootViewController.m`, inside `viewDidLoad`, add:

```objc
UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
[button setTitle:@"Tap Me" forState:UIControlStateNormal];
button.translatesAutoresizingMaskIntoConstraints = NO;
[button addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
[self.view addSubview:button];

[NSLayoutConstraint activateConstraints:@[
    [button.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    [button.topAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:60],
]];
```

Then add the method that runs when tapped (anywhere inside the `@implementation` block):

```objc
- (void)buttonTapped {
    NSLog(@"Button was tapped!");
}
```

### Add a Text Field

```objc
UITextField *textField = [[UITextField alloc] init];
textField.placeholder = @"Type something...";
textField.borderStyle = UITextBorderStyleRoundedRect;
textField.translatesAutoresizingMaskIntoConstraints = NO;
[self.view addSubview:textField];
```

### Add an Image

Put your image file (e.g., `myimage.png`) in the project folder, then add it to `MyApp_FILES` in the Makefile... actually, for images you'd need to set up a resource bundle. For now, the simplest approach is to use SF Symbols (built-in Apple icons):

```objc
UIImageView *imageView = [[UIImageView alloc] init];
imageView.image = [UIImage systemImageNamed:@"star.fill"];
imageView.tintColor = [UIColor systemYellowColor];
imageView.translatesAutoresizingMaskIntoConstraints = NO;
[self.view addSubview:imageView];
```

## The Complete Install-On-Phone Cheat Sheet

Every time you want to install a new build:

```powershell
# 1. Download the IPA from GitHub Actions → Artifacts

# 2. Copy to phone (replace IP with your phone's actual IP)
scp MyApp.ipa root@192.168.X.X:/var/mobile/Documents/

# 3. Install
ssh root@192.168.X.X "appinst /var/mobile/Documents/MyApp.ipa"
```

## How the Build Works (Under the Hood)

When you push to GitHub, this sequence runs on a cloud Mac:

1. **GitHub gives us a fresh Mac VM.** It has Xcode pre-installed (Apple's development toolkit). This is what you'd normally need a physical Mac for.

2. **Theos is installed.** Theos is a build system originally created for building jailbreak tweaks. We use it because it knows how to compile iOS apps and doesn't need the full Xcode project machinery. It uses the same compiler underneath (clang + iOS SDK).

3. **The code compiles.** Your `.m` files are compiled into ARM64 machine code and linked against UIKit/Foundation/CoreGraphics (the frameworks that provide buttons, labels, views, etc.).

4. **The .app bundle is packaged.** The compiled binary, Info.plist, and resources are assembled into a `.app` bundle — this is what an iOS app actually is.

5. **The IPA is created.** The `.app` is put into a `Payload/` folder and zipped. An IPA is literally just a zip file with this specific structure. No signing, no certificates, no encryption.

6. **The IPA is uploaded as an artifact.** You download it and install it on your jailbroken device, where AppSync Unified skips the signature check.

## Troubleshooting

### "Could not connect" when trying SSH
- Make sure your iPhone is awake (screen on)
- Check that OpenSSH is installed in Cydia/Sileo
- Verify the IP address in Settings → Wi-Fi
- Try pinging the phone: `ping 192.168.X.X`

### "appinst: command not found" on the phone
- In Cydia/Sileo, add the repo `https://lukezgd.github.io/repo`
- Install the `appinst` package

### "Signature verification failed" or app doesn't appear
- Make sure AppSync Unified is installed and enabled
- From Cydia, check that AppSync Unified shows as "Installed"
- Try rebooting and re-jailbreaking (AppSync only works in jailbroken state)

### GitHub Actions build fails
- Go to the Actions tab, click the failed build, expand the red step to see the error
- Most common issue: a syntax error in your `.m` files. Check for missing semicolons or brackets.
- If "Install Theos" fails, just re-run the job (click "Re-run jobs" in the top right). Network hiccups happen.

### The app crashes on launch
- Your iPhone iOS version might be lower than the minimum set in the Makefile (`14.0`). Lower it and rebuild.
- SSH into your phone and check the crash log: `cat /var/mobile/Library/Logs/CrashReporter/MyApp*`

### "make: command not found" or Theos not found in build
- The GitHub Actions workflow sets `THEOS=~/theos`. If something changes in the Theos install path, update the workflow file.

## Going Further

Once you're comfortable with this workflow:

- **Write in Swift instead of Objective-C**: Change your `.m` files to `.swift` and add them to `MyApp_SWIFT_FILES` in the Makefile instead of `MyApp_FILES`.
- **Add more screens**: Create new ViewController classes and navigate between them with `UINavigationController`.
- **Use private APIs**: Since you're on a jailbroken device, you can import private frameworks (add them to `MyApp_PRIVATE_FRAMEWORKS`) and call methods Apple doesn't expose to normal apps.
- **Build a tweak instead**: Change `APPLICATION_NAME` to `TWEAK_NAME` and `application.mk` to `tweak.mk` in the Makefile to hook into system processes. This is how most Cydia packages work.

## TL;DR

```
You edit code on PC → git push → GitHub cloud Mac compiles it → download IPA → scp to phone → appinst → app appears on home screen. No Mac. No Apple Developer account. No signing. No expiry. Free.
```
