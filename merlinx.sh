#!/bin/bash

# Konfigurasi Awal
KERNEL_DIR=$(pwd)
OUT_DIR=$KERNEL_DIR/out
ANYKERNEL_DIR=$KERNEL_DIR/AnyKernel3
CONFIG_NAME=merlin_defconfig
THREADS=$(nproc --all)
CLANGDIR=""
DEFCONFIG_FILE="$KERNEL_DIR/arch/arm64/configs/$CONFIG_NAME"
DEVICE_CODENAME="merlin"
HOSTNAME=""
MAKER=""
KERNEL_VERSION=""

# Telegram
BOT_TOKEN=""
CHAT_ID=""

# Telegram Ke Grub
BOT_TOKEN=""
CHAT_ID=""
MESSAGE_THREAD_ID=""

# Fungsi kirim pesan ke Telegram
send_telegram_message() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "message_thread_id=$MESSAGE_THREAD_ID" \
        -d "text=$1" \
        -d "parse_mode=Markdown"
}

# Fungsi kirim file ke Telegram
send_telegram_file() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
        -F "chat_id=$CHAT_ID" \
        -F "document=@$1" \
        -F "message_thread_id=$MESSAGE_THREAD_ID" \
        -F "caption=$2" \
        -F "parse_mode=Markdown"
}

# Ambil LOCALVERSION
RAW_LOCALVERSION=$(grep -oP 'CONFIG_LOCALVERSION="\K[^"]+' "$DEFCONFIG_FILE")
KERNEL_NAME=$(echo "$RAW_LOCALVERSION" | sed 's/^-//')
[ -z "$KERNEL_NAME" ] && KERNEL_NAME="CustomKernel"

# Fix Double Kernel
    rm -rf "$ANYKERNEL_DIR"
    git clone https://github.com/vq6oon/AnyKernel3 -b merlinx "$ANYKERNEL_DIR"

# Bersihkan output lama
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Export build env
export KBUILD_BUILD_USER="$MAKER"
export KBUILD_BUILD_HOST="$HOSTNAME"
export USE_CCACHE=1
ccache -M 30G
export PATH="$CLANGDIR/bin:$PATH"

# Info awal
send_telegram_message "
~~~< *Kurap1ka Compile* >~~~
🔧 *Build Kernel Dimulai!*  
📱 Device: \`$DEVICE_CODENAME\`  
🖥️ Host: \`$HOSTNAME\`  
🧬 Kernel Name: \`$KERNEL_NAME\`  
⚙️ Defconfig: \`$CONFIG_NAME\`"

# Waktu mulai
BUILD_START=$(date +%s)

# Build & log
make O=out ARCH=arm64 $CONFIG_NAME
make -j"$THREADS" O=out LLVM=1 LLVM_IAS=1 \
  ARCH=arm64 \
  CC=clang \
  LD=ld.lld \
  AR=llvm-ar \
  AS=llvm-as \
  NM=llvm-nm \
  STRIP=llvm-strip \
  OBJCOPY=llvm-objcopy \
  OBJDUMP=llvm-objdump \
  READELF=llvm-readelf \
  HOSTCC=clang \
  HOSTCXX=clang++ \
  HOSTAR=llvm-ar \
  HOSTLD=ld.lld \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- | tee -a out/compile.log

# Waktu selesai
BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

# Cek file hasil
KERNEL_IMAGE=$(find $OUT_DIR -name "Image.gz-dtb" | head -n1)

if [ -f "$KERNEL_IMAGE" ]; then
    cp "$KERNEL_IMAGE" "$ANYKERNEL_DIR/Image.gz-dtb"

    cd "$ANYKERNEL_DIR" || exit 1
    ZIP_NAME="$KERNEL_VERSION-${KERNEL_NAME}-$DEVICE_CODENAME-$(date +%Y%m%d-%H%M).zip"
    zip -r9 "$ZIP_NAME" * > /dev/null 2>&1

    if [ -f "$ZIP_NAME" ]; then
        ZIP_SIZE=$(du -h "$ZIP_NAME" | cut -f1)
        ZIP_CHECKSUM=$(sha256sum "$ZIP_NAME" | awk '{print $1}')
        COMPILER_VERSION=$("$CLANGDIR/bin/clang" --version | head -n1)
        KERNEL_VERSION=$KERNEL_VERSION
        
        CAPTION="✅ *Build Selesai Bang!!!*  
🖥️ *Made By:* \`$MAKER\`  
🖥️ *Host:* \`$HOSTNAME\`  
🧬 *Kernel Name:* \`$KERNEL_NAME\`  
📱 *Device:* \`$DEVICE_CODENAME\`  
🧾 *Kernel Version:* \`$KERNEL_VERSION\`

📦 \`$ZIP_NAME\` ($ZIP_SIZE)  
⏱️ ${BUILD_DURATION}s  
🛠 Compiler: \`$COMPILER_VERSION\`  
🔐 SHA256: \`${ZIP_CHECKSUM:0:8}...\`
~~~< *Kurap1ka Compile* >~~~"

        send_telegram_message "🎉 *ZIP Berhasil Dibuat!*"
        send_telegram_file "$ZIP_NAME" "$CAPTION"
    else
        send_telegram_message "❌ *Gagal membuat ZIP!*"
    fi
else
    send_telegram_message "❌ *Build Gagal!* Tidak ditemukan *Image.gz* atau *DTB*!  
📤 Mengirim *build.log*..."
    send_telegram_file "$KERNEL_DIR/out/compile.log" "⚠️ *Log Build Gagal*"
fi
