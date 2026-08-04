# Platform permission notes for LiveKit calls (Phase 2)
#
# After scaffolding platforms (`cd flutter_app && flutter create . --project-name team_app`):
#
# Android — android/app/src/main/AndroidManifest.xml
#   <uses-permission android:name="android.permission.INTERNET"/>
#   <uses-permission android:name="android.permission.CAMERA"/>
#   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
#   <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
#   <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
#   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
#
# iOS — ios/Runner/Info.plist
#   <key>NSCameraUsageDescription</key>
#   <string>Camera is used for video calls</string>
#   <key>NSMicrophoneUsageDescription</key>
#   <string>Microphone is used for voice and video calls</string>
#
# Also ensure backend LIVEKIT_WS_URL points at the reachable LiveKit/TURN endpoint
# (wss://turn.yourhost.ir after TLS is wired).
