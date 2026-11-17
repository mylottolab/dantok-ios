# 단톡방 iOS (단골창구 dangol-ios 에서 가져옴) — Codemagic 이 "npx cap add ios" 로 만든 아이폰 폴더에 우리 설정을 끼워 넣습니다.
# (GitHub 에 폴더를 올리기 어려워서, 폴더는 빌드 때 만들고 파일만 저장소에 둡니다)
import plistlib, shutil, os, re, sys, json
A = 'ios/App/App/'
CFG = json.load(open('capacitor.config.json', encoding='utf-8'))
APP_ID = CFG['appId']            # com.weaveapp.alias · com.weaveapp.aliascall
APP_NAME = CFG.get('appName', '')
# ── Firebase(알림) ─────────────────────────────────────────────
if not os.path.exists('GoogleService-Info.plist'):
    sys.exit('🔴 GoogleService-Info.plist 가 저장소에 없습니다. Firebase → 단톡방 iOS(com.weaveapp.dantok) 에서 받아 올려 주세요.')
g = plistlib.load(open('GoogleService-Info.plist', 'rb'))
if g.get('BUNDLE_ID') != APP_ID:
    sys.exit('🔴 GoogleService-Info.plist 가 이 앱(' + APP_ID + ') 것이 아닙니다: ' + str(g.get('BUNDLE_ID')))
ad = open('AppDelegate.swift').read()
for k, v in {'__GOOGLE_APP_ID__': 'GOOGLE_APP_ID', '__GCM_SENDER_ID__': 'GCM_SENDER_ID', '__API_KEY__': 'API_KEY',
             '__PROJECT_ID__': 'PROJECT_ID', '__BUNDLE_ID__': 'BUNDLE_ID', '__STORAGE_BUCKET__': 'STORAGE_BUCKET'}.items():
    ad = ad.replace(k, str(g.get(v, '')).replace('"', ''))
open(A + 'AppDelegate.swift', 'w').write(ad)

# Firebase 부품을 앱에 넣습니다 (Capacitor 가 만든 부품 목록에 한 줄 더)
pk = 'ios/App/CapApp-SPM/Package.swift'
ps = open(pk).read()
if 'firebase-ios-sdk' not in ps:
    ps = ps.replace('    dependencies: [\n',
        '    dependencies: [\n        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.0.0"),\n', 1)
    ps = ps.replace('            dependencies: [\n',
        '            dependencies: [\n                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),\n', 1)
    assert 'FirebaseMessaging' in ps, 'Package.swift 모양이 예상과 다릅니다'
    open(pk, 'w').write(ps)
shutil.copy('App.entitlements', A + 'App.entitlements')
shutil.copy('AppIcon.png', A + 'Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png')
for n in ['splash-2732x2732.png', 'splash-2732x2732-1.png', 'splash-2732x2732-2.png']:
    shutil.copy('Splash.png', A + 'Assets.xcassets/Splash.imageset/' + n)

p = A + 'Info.plist'
d = plistlib.load(open(p, 'rb'))
d['CFBundleDevelopmentRegion'] = 'ko'
d['CFBundleDisplayName'] = APP_NAME or '단톡방'
d['UIRequiredDeviceCapabilities'] = ['arm64']
d['UISupportedInterfaceOrientations'] = ['UIInterfaceOrientationPortrait']
d.pop('UISupportedInterfaceOrientations~ipad', None)
d['UIBackgroundModes'] = ['remote-notification']   # 단톡방: 알림만 (전화 없음)
d['NSCameraUsageDescription'] = '단톡방에 사진 · 동영상을 찍어 올리거나 프로필 사진을 찍을 때 카메라를 씁니다.'
d['NSMicrophoneUsageDescription'] = '음성 메시지를 녹음하거나 동영상을 찍을 때 마이크를 씁니다.'
d['NSPhotoLibraryUsageDescription'] = '단톡방과 내 갤러리에 사진 · 동영상을 올리려면 사진 보관함을 엽니다.'
d['NSPhotoLibraryAddUsageDescription'] = '단톡방에서 받은 사진을 휴대폰에 저장할 때 씁니다.'
d['ITSAppUsesNonExemptEncryption'] = False
plistlib.dump(d, open(p, 'wb'))

p = 'ios/App/App.xcodeproj/project.pbxproj'
s = open(p).read()
key = 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n'
if 'CODE_SIGN_ENTITLEMENTS' not in s:
    assert s.count(key) == 2, 'pbxproj 모양이 예상과 다릅니다'
    s = s.replace(key, key + '\t\t\t\tCODE_SIGN_ENTITLEMENTS = App/App.entitlements;\n')
s = s.replace('TARGETED_DEVICE_FAMILY = "1,2";', 'TARGETED_DEVICE_FAMILY = 1;')
# 🔴 앱 버전(App Store 에 보이는 번호). 1.0 심사 통과 뒤 첫 업데이트 = 1.1
APP_VERSION = '1.0'   # 💬 단톡방 첫 출시
s = re.sub(r'MARKETING_VERSION = [^;]+;', 'MARKETING_VERSION = ' + APP_VERSION + ';', s)
open(p, 'w').write(s)
print(APP_NAME + ' iOS 설정을 넣었습니다 (' + APP_ID + ')')
