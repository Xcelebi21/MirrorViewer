# MirrorViewer (native IPA builder)

## Improved version – what changed
- No more black screen: first launch → URL prompt; **Cancel** loads the default URL instead of nothing.
- Friendly fallback when the server can't be reached (Tap Retry / Change URL instead of a frozen black view).
- True immersive full-screen (status bar & home indicator hidden) via `prefersStatusBarHidden`/`prefersHomeIndicatorAutoHidden`.
- Loading spinner while connecting.
- Typing just an IP:port now auto-appends `/vnc.html` and `?autoconnect=true&resize=scale&path=websockify`, so touch→mouse mapping starts immediately.
- URLs are saved: relaunch auto-connects, no re-typing.

> If you see "Failed to connect" in noVNC, change the URL and remove the `&path=websockify` part — TrollVNC's bundled web server sometimes doesn't want it.

Builds a small unsigned iOS app that shows the other phone's **noVNC** endpoint full-screen.

## What it does
- `WKWebView` fills the screen, no browser chrome.
- First launch asks for the noVNC URL (e.g. `http://100.x.y.z:8081/vnc.html`), saves it, then reloads automatically.

## Build the IPA (no Mac of your own needed)
1. Push this folder to a new GitHub repo; the workflow at `.github/workflows/build.yml` runs on the free macOS runners.
   ```
   git init
   git add .
   git commit -m "MirrorViewer"
   git branch -M main
   gh repo create MirrorViewer --public --source=. --push
   ```
   Or run **Actions → Build IPA → Run workflow** manually with `gh workflow run build.yml`.
2. Wait for the job to finish, then download the `MirrorViewerUnsigned` artifact from the run page.

## Install on the other phone (the viewer)
The build is unsigned, so self-sign it. On Windows use Sideloadly/AltStore with your Apple ID:
- Drag `MirrorViewerUnsigned.ipa` into Sideloadly, enter your Apple ID, install on the viewer phone.
- Or, if the viewer phone is jailbroken with TrollStore, just sideload the IPA straight into TrollStore.

## Jailbroken / target phone setup
1. Install TrollVNC on the device you want to view.
2. Start it with the HTTP/browser client and password auth, bound to your tailnet IP:
   ```
   trollvncserver -p 5901 -H 8081 -b 100.x.y.z -A 30
   ```
3. Open `http://100.x.y.z:8081/vnc.html` in MirrorViewer (or Safari) on the other phone.

## Things to know
- Works over Tailscale (both phones on the same tailnet), or same LAN.
- Touch works because noVNC translates touch to mouse events.
- Real-device test still needed: TrollVNC on iOS 16 + palera1n is not verified here.
- If you prefer zero code, see the noVNC `Add to Home Screen` route from our chat notes — no IPA required.
