#!/bin/bash
# 안드로이드 APK 빌드: Godot 내보내기 → apksig 로 서명 → build/everin.apk
# Android SDK 없이 동작한다 (Godot 이 요구하는 SDK 폴더는 빈 자리표시용으로 만든다).
# 사용법: tools/build_apk.sh
set -e
VER=4.5.1-stable
CACHE="${GODOT_DIR:-$HOME/.cache/godot}"
GODOT="$CACHE/Godot_v${VER}_linux.x86_64"
TPL="$HOME/.local/share/godot/export_templates/${VER/-/.}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
KS="${EVERIN_KEYSTORE:-$CACHE/everin.keystore}"
KS_PASS="${EVERIN_KEYSTORE_PASS:-everin123}"
JFLAGS="--add-exports java.base/sun.security.x509=ALL-UNNAMED --add-exports java.base/sun.security.pkcs=ALL-UNNAMED --add-exports java.base/sun.security.util=ALL-UNNAMED"
mkdir -p "$CACHE"

# 1) Godot 에디터
if [ ! -x "$GODOT" ]; then
  echo "Godot 내려받는 중..."
  curl -sSL -o "$CACHE/godot.zip" "https://github.com/godotengine/godot/releases/download/${VER}/Godot_v${VER}_linux.x86_64.zip"
  unzip -o -q "$CACHE/godot.zip" -d "$CACHE" && rm "$CACHE/godot.zip"
fi
# 2) 안드로이드 내보내기 템플릿 (1.3GB 묶음에서 안드로이드 파일만 꺼냄)
if [ ! -f "$TPL/android_debug.apk" ]; then
  echo "내보내기 템플릿 내려받는 중 (약 1.3GB)..."
  curl -sSL -o "$CACHE/templates.tpz" "https://github.com/godotengine/godot/releases/download/${VER}/Godot_v${VER}_export_templates.tpz"
  mkdir -p "$TPL"
  unzip -o -j -q "$CACHE/templates.tpz" templates/android_debug.apk templates/android_release.apk templates/version.txt -d "$TPL"
  rm "$CACHE/templates.tpz"
fi
# 3) 서명 도구 (Maven Central 의 apksig) + 서명 키
[ -f "$CACHE/apksig.jar" ] || curl -sSL -o "$CACHE/apksig.jar" https://repo1.maven.org/maven2/com/android/tools/build/apksig/2.3.0/apksig-2.3.0.jar
javac -d "$CACHE" -cp "$CACHE/apksig.jar" "$PROJECT/tools/SignApk.java"
if [ ! -f "$KS" ]; then
  keytool -genkeypair -keystore "$KS" -alias everin -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$KS_PASS" -keypass "$KS_PASS" -dname "CN=Everin, O=Everin, C=KR" >/dev/null 2>&1
  echo "새 서명 키를 만들었습니다: $KS (키가 바뀌면 폰에서 기존 앱을 지우고 설치해야 합니다)"
fi
# 4) Godot 이 존재만 확인하는 SDK 폴더
SDK="$HOME/Android/Sdk"
if [ ! -x "$SDK/build-tools/35.0.0/apksigner" ]; then
  mkdir -p "$SDK/platform-tools" "$SDK/build-tools/35.0.0"
  printf '#!/bin/bash\nexit 0\n' > "$SDK/platform-tools/adb"
  printf '#!/bin/bash\nexit 0\n' > "$SDK/build-tools/35.0.0/apksigner"
  chmod +x "$SDK/platform-tools/adb" "$SDK/build-tools/35.0.0/apksigner"
fi
# 5) 내보내기 + 서명
cd "$PROJECT"
mkdir -p build
timeout 300 "$GODOT" --headless --import >/dev/null 2>&1 || true
timeout 600 "$GODOT" --headless --export-debug "Android" build/everin-unsigned.apk 2>&1 | grep -E "ERROR|error" || true
[ -s build/everin-unsigned.apk ] || { echo "내보내기 실패"; exit 1; }
rm -f build/everin.apk
java $JFLAGS -cp "$CACHE/apksig.jar:$CACHE" SignApk "$KS" "$KS_PASS" everin build/everin-unsigned.apk build/everin.apk 2>&1 | grep -vE "JAVA_TOOL|_JAVA_OPTIONS"
rm -f build/everin-unsigned.apk
ls -la build/everin.apk
