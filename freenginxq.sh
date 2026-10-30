#!/usr/bin/env bash
# Build freenginx from source with bundled zlib/PCRE2/OpenSSL and third-party modules.
# Installing is left to you: cd into the freenginx source dir and run `sudo make install`.
#
# Every setting below can be overridden from the environment, e.g.
#   V_NGINX=1.31.6 BUILDROOT=/tmp/free ./freenginx.sh -v
set -Eeuo pipefail

### Versions
: "${V_NGINX:=1.31.5}"
: "${V_ZLIB:=1.3.2}"
: "${V_PCRE:=10.49}"
: "${V_QSSL:=3.6.5}"
: "${V_MAXM:=1.14.1}"
: "${V_HEAD:=0.41}"

### Build settings
: "${BUILDROOT:=$HOME/Gits/free}"
: "${JOBS:=$(nproc)}"
: "${LOG:=}"           # default: $BUILDROOT/build-<version>-<timestamp>.log
: "${VERBOSITY:=1}"    # 0 = quiet, 1 = steps only, 2 = everything
: "${CLEAN:=0}"

### Optional features (1 = on, 0 = off)
: "${USE_BROTLI:=1}"
: "${USE_ZSTD:=1}"
: "${USE_GEOIP2:=1}"
: "${USE_HEADERS:=1}"
: "${USE_KTLS:=1}"
: "${USE_DEBUG:=1}"
: "${USE_ASM:=0}"      # OpenSSL assembly (AES-NI etc.); 0 builds with no-asm

usage() {
  cat <<EOF
Usage: ${0##*/} [options]

  -r DIR    build root (default: $BUILDROOT)
  -j N      parallel jobs (default: $JOBS)
  -l FILE   log file (default: <build root>/build-$V_NGINX-<timestamp>.log)
  -q        quiet: print only errors and the final summary
  -v        verbose: stream all build output to the terminal (still logged)
  -c        run 'make clean' in the freenginx tree before configuring
  --purge   don't build; delete this version's source and dependency folders
            (run after 'sudo make install'; logs are kept)
  --no-brotli | --no-zstd | --no-geoip2 | --no-headers | --no-ktls | --no-debug
            disable an optional feature
  --asm     build OpenSSL with assembly optimizations (default: no-asm)
  -h        show this help

Versions come from the top of the script or the environment:
  V_NGINX V_ZLIB V_PCRE V_QSSL V_MAXM V_HEAD
EOF
}

while [ $# -gt 0 ]; do
  case $1 in
    -r) BUILDROOT=${2:?-r needs a directory}; shift ;;
    -j) JOBS=${2:?-j needs a number}; shift ;;
    -l) LOG=${2:?-l needs a file}; shift ;;
    -q) VERBOSITY=0 ;;
    -v) VERBOSITY=2 ;;
    -c) CLEAN=1 ;;
    --purge) PURGE=1 ;;
    --no-brotli)  USE_BROTLI=0 ;;
    --no-zstd)    USE_ZSTD=0 ;;
    --no-geoip2)  USE_GEOIP2=0 ;;
    --no-headers) USE_HEADERS=0 ;;
    --no-ktls)    USE_KTLS=0 ;;
    --no-debug)   USE_DEBUG=0 ;;
    --asm)        USE_ASM=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

### Logging: everything goes to $LOG; the terminal gets steps (1) or everything (2).
log()  { printf '%s\n' "$*" >>"$LOG"; }
step() {
  if [ "$VERBOSITY" -ge 1 ]; then printf '==> %s\n' "$*"; fi
  printf '\n==> [%s] %s\n' "$(date +%T)" "$*" >>"$LOG"
}
run() {
  log "+ $*"
  if [ "$VERBOSITY" -ge 2 ]; then "$@" 2>&1 | tee -a "$LOG"; else "$@" >>"$LOG" 2>&1; fi
}
on_error() {
  local rc=$?
  echo "!! Build failed (exit $rc, line $1). Full log: $LOG" >&2
  if [ "$VERBOSITY" -lt 2 ]; then tail -n 30 "$LOG" >&2; fi
  exit "$rc"
}

### Helpers
fetch() { # url dir: download and extract into $BUILDROOT unless dir already exists
  local url=$1 dir=$2 file=${1##*/}
  if [ -d "$dir" ]; then step "$dir (cached)"; return 0; fi
  step "Downloading $dir"
  run curl -fsSL -o "$file" "$url"
  case $file in
    *.zip) run unzip -q "$file" ;;
    *)     run tar -xzf "$file" ;;
  esac
  rm -f "$file"
}

sync_git() { # url dir: clone, or fast-forward an existing clone
  if [ -d "$2/.git" ]; then
    step "Updating $2"
    run git -C "$2" pull --ff-only
  else
    step "Cloning $2"
    run git clone "$1" "$2"
  fi
  run git -C "$2" submodule update --init --recursive --jobs "$JOBS"
}

ktls_supported() { # kernel >= 5.10
  local maj min
  IFS=. read -r maj min _ <<<"$(uname -r)"
  [ "$maj" -gt 5 ] || { [ "$maj" -eq 5 ] && [ "$min" -ge 10 ]; }
}

build_brotli() {
  local src=ngx-brotli/deps/brotli
  local flags="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections"
  step "Building brotli"
  run cmake -S "$src" -B "$src/out" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="$flags" -DCMAKE_CXX_FLAGS="$flags" -DCMAKE_INSTALL_PREFIX=./installed
  run cmake --build "$src/out" --config Release --target brotlienc -j "$JOBS"
}

install_maxmind() { # system-wide, skipped when pkg-config already reports $V_MAXM
  local dir=libmaxminddb-$V_MAXM have
  have=$(pkg-config --modversion libmaxminddb 2>/dev/null || true)
  if [ "$have" = "$V_MAXM" ]; then step "libmaxminddb $have already installed"; return 0; fi
  log "pkg-config reports libmaxminddb '${have:-none}', want $V_MAXM"
  fetch "https://github.com/maxmind/libmaxminddb/releases/download/$V_MAXM/$dir.tar.gz" "$dir"
  step "Installing $dir system-wide (sudo)"
  cd "$dir"
  run ./configure
  run make -j "$JOBS"
  run sudo make install
  run sudo ldconfig
  cd "$BUILDROOT"
}

### Setup
case $BUILDROOT in /*) ;; *) BUILDROOT=$PWD/$BUILDROOT ;; esac

if [ "${PURGE:-0}" = 1 ]; then
  built=$BUILDROOT/nginx-release-$V_NGINX/objs/nginx
  if [ -f "$built" ] && ! cmp -s "$built" /usr/sbin/nginx; then
    echo "!! $built is not the installed /usr/sbin/nginx. Run 'sudo make install' first." >&2
    exit 1
  fi
  echo "==> Removing freenginx $V_NGINX build folders from $BUILDROOT"
  rm -rf -- "$BUILDROOT/nginx-release-$V_NGINX" "$BUILDROOT/zlib-$V_ZLIB" "$BUILDROOT/pcre2-$V_PCRE" \
    "$BUILDROOT/openssl-$V_QSSL" "$BUILDROOT/libmaxminddb-$V_MAXM" "$BUILDROOT/nginx-geoip2" \
    "$BUILDROOT/ngx-brotli" "$BUILDROOT/ngx-zstd" "$BUILDROOT/headers-more-nginx-module-$V_HEAD"
  exit 0
fi

mkdir -p "$BUILDROOT"
: "${LOG:=$BUILDROOT/build-$V_NGINX-$(date +%Y%m%d-%H%M%S).log}"
case $LOG in /*) ;; *) LOG=$PWD/$LOG ;; esac
mkdir -p "$(dirname "$LOG")"
: >"$LOG"
trap 'on_error $LINENO' ERR
cd "$BUILDROOT"

missing=()
for t in curl tar unzip git cmake make cc pkg-config; do command -v "$t" >/dev/null || missing+=("$t"); done
if [ ${#missing[@]} -gt 0 ]; then echo "Missing required tools: ${missing[*]}" >&2; exit 1; fi

step "freenginx $V_NGINX in $BUILDROOT (log: $LOG)"
set | grep -E '^(V_[A-Z]+|USE_[A-Z0-9]+|JOBS|BUILDROOT|VERBOSITY|CLEAN)=' >>"$LOG"

### Sources
fetch "https://www.zlib.net/zlib-$V_ZLIB.tar.gz" "zlib-$V_ZLIB"
fetch "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$V_PCRE/pcre2-$V_PCRE.tar.gz" "pcre2-$V_PCRE"
fetch "https://github.com/openssl/openssl/releases/download/openssl-$V_QSSL/openssl-$V_QSSL.tar.gz" "openssl-$V_QSSL"
fetch "https://github.com/freenginx/nginx/archive/refs/tags/release-$V_NGINX.tar.gz" "nginx-release-$V_NGINX"

### Optional modules (BUILD_INFO order matches the old hardcoded string)
info=() mods=()
if [ "$USE_GEOIP2" = 1 ]; then
  install_maxmind
  sync_git https://github.com/leev/ngx_http_geoip2_module nginx-geoip2
  info+=(GeoIP2); mods+=(--add-module=../nginx-geoip2)
fi
if [ "$USE_BROTLI" = 1 ]; then
  sync_git https://github.com/google/ngx_brotli ngx-brotli
  build_brotli
  info+=(Brotli); mods+=(--add-module=../ngx-brotli)
fi
if [ "$USE_ZSTD" = 1 ]; then
  sync_git https://github.com/HanadaLee/ngx_http_zstd_module.git ngx-zstd
  info+=(Zstd); mods+=(--add-module=../ngx-zstd)
fi
info+=(H3)
if [ "$USE_HEADERS" = 1 ]; then
  fetch "https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v$V_HEAD.zip" "headers-more-nginx-module-$V_HEAD"
  info+=(Headers-More); mods+=(--add-module=../headers-more-nginx-module-$V_HEAD)
fi
info+=(Quantum)
if [ "$USE_DEBUG" = 1 ]; then info+=(debug); mods+=(--with-debug); fi
ssl_opt="no-tests enable-tls1_3"
if [ "$USE_ASM" = 0 ]; then ssl_opt="no-asm $ssl_opt"; fi
ktls_opt=""
if [ "$USE_KTLS" = 1 ]; then
  if ktls_supported; then
    step "Enabling kTLS (sudo)"
    run sudo modprobe tls
    ktls_opt=" enable-ktls"
    info+=(KTLS)
  else
    step "Kernel $(uname -r) is older than 5.10, skipping kTLS"
  fi
fi
build_info="w/$(IFS=,; echo "${info[*]}")"

### Configure and build
SRC=$BUILDROOT/nginx-release-$V_NGINX
cd "$SRC"
if [ "$CLEAN" = 1 ] && [ -f Makefile ]; then
  step "Cleaning previous build"
  run make clean
fi

step "Configuring freenginx ($build_info)"
run ./auto/configure \
  --build="$build_info" \
  --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --modules-path=/usr/lib/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx.pid \
  --lock-path=/var/run/nginx.lock \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --user=nginx --group=nginx \
  --with-compat --with-file-aio --with-threads \
  --with-http_addition_module --with-http_auth_request_module --with-http_dav_module \
  --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module \
  --with-http_realip_module --with-http_secure_link_module --with-http_slice_module \
  --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module \
  --with-http_v2_module --with-http_v3_module \
  --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module \
  --with-select_module --with-poll_module \
  --with-zlib="../zlib-$V_ZLIB" \
  --with-pcre="../pcre2-$V_PCRE" \
  --with-openssl="../openssl-$V_QSSL" \
  --with-openssl-opt="$ssl_opt$ktls_opt" \
  "${mods[@]}" \
  --with-cc-opt="-g -O2 -ffile-prefix-map=/data/builder/debuild/nginx-$V_NGINX/debian/debuild-base/nginx-$V_NGINX=. -flto=auto -ffat-lto-objects -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC -I../openssl-$V_QSSL/build/include" \
  --with-ld-opt="-Wl,-Bsymbolic-functions -flto=auto -ffat-lto-objects -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie -L../openssl-$V_QSSL/build/lib"

step "Compiling with $JOBS jobs (this takes a while)"
run make -j "$JOBS"

### Summary (always shown, even with -q)
{
  echo
  "$SRC/objs/nginx" -V 2>&1
  ls -lh "$SRC/objs/nginx"
  echo
  echo "Log:     $LOG"
  echo "Install: cd $SRC && sudo make install"
  printf 'Total compile time: %dm %02ds\n' $((SECONDS / 60)) $((SECONDS % 60))
} | tee -a "$LOG"
