#!/bin/sh
####################################
### START change these variables ###
####################################
V_NGINX="1.27.5"
V_ZLIB="1.3.1"
V_PCRE="10.45"
V_QSSL="3.1.7"
V_MAXM="1.12.2"
V_HEAD="0.38"
BUILDROOT="/home/iamdoubz/Gits/freenginx-custom"
####################################
#### END change these variables ####
####################################
CURRENTDIR="$BUILDROOT"
if [ ! -d "$CURRENTDIR" ]; then
  echo "Creating Build Directory at $BUILDROOT"
  mkdir -p "$CURRENTDIR"
fi
cd "$CURRENTDIR"
### START check dependencies ###
CURRENTDIR="$BUILDROOT/zlib-$V_ZLIB"
if [ ! -d "$CURRENTDIR" ]; then
  echo "zlib Downloading..."
  curl -L -O "https://www.zlib.net/zlib-$V_ZLIB.tar.gz"
  echo "zlib Extracting..."
  tar -xzf "zlib-$V_ZLIB.tar.gz"
  rm "zlib-$V_ZLIB.tar.gz"
fi
CURRENTDIR="$BUILDROOT/pcre2-$V_PCRE"
if [ ! -d "$CURRENTDIR" ]; then
  echo "pcre2 Downloading..."
  curl -L -O "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$V_PCRE/pcre2-$V_PCRE.tar.gz"
  echo "pcre2 Extracting..."
  tar -xzf "pcre2-$V_PCRE.tar.gz"
  rm "pcre2-$V_PCRE.tar.gz"
fi
CURRENTDIR="$BUILDROOT/openssl-openssl-$V_QSSL-quic1"
if [ ! -d "$CURRENTDIR" ]; then
  echo "openssl Downloading..."
  curl -L -O  "https://github.com/quictls/openssl/archive/refs/tags/openssl-$V_QSSL-quic1.zip"
  echo "openssl Extracting..."
  unzip "openssl-$V_QSSL-quic1.zip"
  rm "openssl-$V_QSSL-quic1.zip"
fi
CURRENTDIR="$BUILDROOT/headers-more-nginx-module-$V_HEAD"
if [ ! -d "$CURRENTDIR" ]; then
  echo "Headers More Downloading..."
  curl -L -O "https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v$V_HEAD.zip"
  echo "Headers More Extracting..."
  unzip "v$V_HEAD.zip"
  rm "v$V_HEAD.zip"
fi
#### END check dependencies ####
CURRENTDIR="$BUILDROOT"
cd "$CURRENTDIR"
### START brotli build ###
CURRENTDIR="$BUILDROOT/ngx-brotli"
if [ ! -d "$CURRENTDIR" ]; then
  git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli ngx-brotli
fi
cd "$CURRENTDIR"
git pull
CURRENTDIR="$BUILDROOT/ngx-brotli/deps/brotli/out"
if [ ! -d "$CURRENTDIR" ]; then
  mkdir -p "$CURRENTDIR"
fi
cd "$CURRENTDIR"
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
      -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
cmake --build . --config Release --target brotlienc
CURRENTDIR="$BUILDROOT"
cd "$CURRENTDIR"
### START geoip2
CURRENTDIR="$BUILDROOT/nginx-geoip2"
if [ ! -d "$CURRENTDIR" ]; then
  git clone https://github.com/leev/ngx_http_geoip2_module nginx-geoip2
fi
cd "$CURRENTDIR"
git pull
CURRENTDIR="$BUILDROOT"
cd "$CURRENTDIR"
### START libmaxminddb
CURRENTDIR="$BUILDROOT/libmaxminddb-$V_MAXM"
if [ ! -d "$CURRENTDIR" ]; then
  echo "MaxMind downloading..."
  curl -L -O "https://github.com/maxmind/libmaxminddb/releases/download/$V_MAXM/libmaxminddb-$V_MAXM.tar.gz"
  echo "MaxMind Extracting..."
  tar -xzf "libmaxminddb-$V_MAXM.tar.gz"
  rm "libmaxminddb-$V_MAXM.tar.gz"
  cd "libmaxminddb-$V_MAXM"
  ./configure
  make
  sudo make install
  # sudo sh -c "echo /usr/local/lib  >> /etc/ld.so.conf.d/local.conf"
  sudo ldconfig
fi
CURRENTDIR="$BUILDROOT"
cd "$CURRENTDIR"
### START nginx config ###
CURRENTDIR="$BUILDROOT/nginx-release-$V_NGINX"
if [ ! -d "$CURRENTDIR" ]; then
  curl -L -O "https://github.com/freenginx/nginx/archive/refs/tags/release-$V_NGINX.tar.gz"
  tar -xzf "release-$V_NGINX.tar.gz"
  rm "release-$V_NGINX.tar.gz"
fi
cd "$CURRENTDIR"
make clean
./auto/configure --build="w/GeoIP2,Brotli,H3,Headers-More,debug" --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log \
                 --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
                 --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
                 --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module \
                 --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module \
                 --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-mail --with-mail_ssl_module \
                 --with-http_v2_module --with-http_v3_module --with-stream --with-select_module --with-poll_module --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module \
                 --with-debug --with-zlib=../zlib-$V_ZLIB --with-pcre=../pcre2-$V_PCRE --with-openssl=../openssl-openssl-$V_QSSL-quic1 --with-openssl-opt='no-asm no-tests' \
                 --add-module='../ngx-brotli' --add-module='../nginx-geoip2' --add-module="../headers-more-nginx-module-$V_HEAD" \
                 --with-cc-opt="-g -O2 -ffile-prefix-map=/data/builder/debuild/nginx-$V_NGINX/debian/debuild-base/nginx-$V_NGINX=. -flto=auto -ffat-lto-objects -flto=auto -ffat-lto-objects -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC -I../openssl-openssl-$V_QSSL-quic1/build/include" \
                 --with-ld-opt="-Wl,-Bsymbolic-functions -flto=auto -ffat-lto-objects -flto=auto -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie -L../openssl-openssl-$V_QSSL-quic1/build/lib"

make -j8
echo " "
$BUILDROOT/nginx-release-$V_NGINX/objs/nginx -V
echo " "
ls -lh $BUILDROOT/nginx-release-$V_NGINX/objs/nginx
