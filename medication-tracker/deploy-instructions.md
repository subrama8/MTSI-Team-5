# Deploy to iPhone Instructions

## Option 1: Local Network Testing

1. **Start the development server:**
   ```bash
   cd medication-tracker
   npm run dev -- --host
   ```

2. **Find your computer's IP address:**
   - Mac: Go to System Preferences > Network
   - Look for your IP (e.g., 192.168.1.100)

3. **Access on iPhone:**
   - Connect iPhone to same WiFi network
   - Open Safari, go to `http://YOUR_IP:3000`
   - Tap Share > Add to Home Screen

## Option 2: Deploy to Web Host

1. **Build for production:**
   ```bash
   npm run build
   ```

2. **Deploy `dist/` folder to any web host:**
   - Netlify (free): Drag and drop the `dist` folder
   - Vercel (free): Connect GitHub repo
   - GitHub Pages: Upload to gh-pages branch

3. **Install on iPhone:**
   - Visit your deployed URL in Safari
   - Add to Home Screen

## Option 3: Using Ngrok for Testing

1. **Install ngrok:**
   ```bash
   npm install -g ngrok
   ```

2. **Start app and create tunnel:**
   ```bash
   npm run dev &
   ngrok http 3000
   ```

3. **Use the ngrok URL on iPhone**

## PWA Features on iOS

Once installed, your app will have:
- ✅ Native app icon on home screen
- ✅ Full screen experience (no Safari bars)
- ✅ Push notifications
- ✅ Offline functionality
- ✅ Camera access for eye tracking
- ✅ All medication tracking features

The PWA behaves exactly like a native app on iOS!