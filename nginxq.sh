#!/bin/sh
####################################
### START change these variables ###
####################################
V_NGINX="1.29.0"
V_ZLIB="1.3.1"
V_PCRE="10.45"
V_QSSL="3.5.1"
V_MAXM="1.12.2"
V_HEAD="0.38"
USE_KTLS=""
BUILD_INFO="w/GeoIP2,Brotli,H3,Headers-More,Quantum,debug"
BUILDROOT="/home/iamdoubz/Gits/nginx-custom"
####################################
#### END change these variables ####
####################################
kernelcheck(){
  MAJOR_VERSION=$(uname -r | awk -F '.' '{print $1}')
  MINOR_VERSION=$(uname -r | awk -F '.' '{print $2}')
  if [ $MAJOR_VERSION -ge 5 ] && [ $MINOR_VERSION -gt 9 ] || [ $MAJOR_VERSION -ge 6 ] ; then
    return true
  else
    return false
  fi
}

check_dir()
{
  path=$1
  what=$2
  if [ ! -d "$path" ]; then
    if [ $what = "create" ]; then
      echo " "
      echo "Creating directory at $path"
      mkdir -p "$path"
    elif [ $what = "zlib" ]; then
      echo " "
      echo "zlib Downloading..."
      curl -s -L -O "https://www.zlib.net/zlib-$V_ZLIB.tar.gz"
      echo "zlib Extracting..."
      tar -xzf "zlib-$V_ZLIB.tar.gz"
      rm "zlib-$V_ZLIB.tar.gz"
    elif [ $what = "pcre" ]; then
      echo " "
      echo "pcre2 Downloading..."
      curl -s -L -O "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$V_PCRE/pcre2-$V_PCRE.tar.gz"
      echo "pcre2 Extracting..."
      tar -xzf "pcre2-$V_PCRE.tar.gz"
      rm "pcre2-$V_PCRE.tar.gz"
    elif [ $what = "openssl" ]; then
      echo " "
      echo "openssl Downloading..."
      curl -s -L -O "https://github.com/openssl/openssl/releases/download/openssl-$V_QSSL/openssl-$V_QSSL.tar.gz"
      echo "openssl Extracting..."
      tar -xzf "openssl-$V_QSSL.tar.gz"
      rm "openssl-$V_QSSL.tar.gz"
    elif [ $what = "headers" ]; then
      echo " "
      echo "Headers More Downloading..."
      curl -s -L -O "https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v$V_HEAD.zip"
      echo "Headers More Extracting..."
      unzip -qq "v$V_HEAD.zip"
      rm "v$V_HEAD.zip"
    elif [ $what = "brotli" ]; then
      echo " "
      echo "Brotli Downloading..."
      git clone --quiet --recurse-submodules -j8 https://github.com/google/ngx_brotli ngx-brotli
    elif [ $what = "geoip2" ]; then
      echo " "
      echo "GeoIP2 Downloading..."
      git clone --quiet https://github.com/leev/ngx_http_geoip2_module nginx-geoip2
    elif [ $what = "maxmind" ]; then
      echo " "
      echo "MaxMind downloading..."
      curl -s -L -O "https://github.com/maxmind/libmaxminddb/releases/download/$V_MAXM/libmaxminddb-$V_MAXM.tar.gz"
      echo "MaxMind Extracting..."
      tar -xzf "libmaxminddb-$V_MAXM.tar.gz"
      rm "libmaxminddb-$V_MAXM.tar.gz"
      cd "libmaxminddb-$V_MAXM"
      ./configure &>/dev/null
      make &>/dev/null
      sudo make install &>/dev/null
      # sudo sh -c "echo /usr/local/lib  >> /etc/ld.so.conf.d/local.conf"
      sudo ldconfig &>/dev/null
    elif [ $what = "ktls" ]; then
      if [ kernelcheck ] ; then
        echo " "
        echo "Enabling KTLS..."
        sudo modprobe tls
        USE_KTLS=" enable-ktls"
        BUILD_INFO="$BUILD_INFO,KTLS"
      fi
    elif [ $what = "nginx" ]; then
      echo " "
      echo "nginx Downloading..."
      curl -s -L -O "https://nginx.org/download/nginx-$V_NGINX.tar.gz"
      tar -xzf "nginx-$V_NGINX.tar.gz"
      rm "nginx-$V_NGINX.tar.gz"
    else
      echo " "
      echo "Path: $path What: $what"
    fi
  fi
}

### Main script start
# Create build directory

CURRENTDIR="$BUILDROOT"
check_dir $CURRENTDIR create
cd "$CURRENTDIR"

# zlib
CURRENTDIR="$BUILDROOT/zlib-$V_ZLIB"
check_dir $CURRENTDIR zlib

# pcre
CURRENTDIR="$BUILDROOT/pcre2-$V_PCRE"
check_dir $CURRENTDIR pcre

# openssl
CURRENTDIR="$BUILDROOT/openssl-$V_QSSL"
check_dir $CURRENTDIR openssl

# headers
CURRENTDIR="$BUILDROOT/headers-more-nginx-module-$V_HEAD"
check_dir $CURRENTDIR headers

# brotli
CURRENTDIR="$BUILDROOT/ngx-brotli"
check_dir $CURRENTDIR brotli
cd "$CURRENTDIR"
git pull --quiet
CURRENTDIR="$BUILDROOT/ngx-brotli/deps/brotli/out"
check_dir $CURRENTDIR create
cd "$CURRENTDIR"
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
      -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed .. &>/dev/null
cmake --build . --config Release --target brotlienc &>/dev/null

# geoip2
CURRENTDIR="$BUILDROOT"
cd "$CURRENTDIR"
CURRENTDIR="$BUILDROOT/nginx-geoip2"
check_dir $CURRENTDIR geoip2
cd "$CURRENTDIR"
git pull --quiet

# maxmind
CURRENTDIR="$BUILDROOT"
cd "$CURRENTDIR"
CURRENTDIR="$BUILDROOT/libmaxminddb-$V_MAXM"
check_dir $CURRENTDIR maxmind

#ktls
CURRENTDIR="$BUILDROOT"
cd "$CURRENTDIR"
CURRENTDIR="$BUILDROOT/ktls"
check_dir $CURRENTDIR ktls

# nginx
CURRENTDIR="$BUILDROOT"
cd "$CURRENTDIR"
CURRENTDIR="$BUILDROOT/nginx-$V_NGINX"
check_dir $CURRENTDIR nginx
cd "$CURRENTDIR"
echo " "
echo " "
echo "Configuring nginx..."
make clean &>/dev/null
./configure --build="$BUILD_INFO" --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log \
            --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
            --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
            --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module \
            --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module \
            --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-mail --with-mail_ssl_module \
            --with-http_v2_module --with-http_v3_module --with-stream --with-select_module --with-poll_module --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module \
            --with-zlib=../zlib-$V_ZLIB --with-pcre=../pcre2-$V_PCRE --with-openssl=../openssl-$V_QSSL --with-openssl-opt="no-asm no-tests enable-tls1_3$USE_KTLS" \
            --add-module='../ngx-brotli' --add-module='../nginx-geoip2' --add-module="../headers-more-nginx-module-$V_HEAD" \
            --with-cc-opt="-g -O2 -ffile-prefix-map=/data/builder/debuild/nginx-$V_NGINX/debian/debuild-base/nginx-$V_NGINX=. -flto=auto -ffat-lto-objects -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC -I../openssl-$V_QSSL/build/include" \
            --with-ld-opt="-Wl,-Bsymbolic-functions -flto=auto -ffat-lto-objects -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie -L../openssl-$V_QSSL/build/lib" \
            --with-debug > config.log
echo " "
make -j8 > make.log
echo " "
$BUILDROOT/nginx-$V_NGINX/objs/nginx -V
echo " "
ls -lh $BUILDROOT/nginx-$V_NGINX/objs/nginx
