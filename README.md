# freenginx-custom
Iamdoubz custom freenginx config for Ubuntu 22.04. I was tired of forgetting what I used to compile [freenginx](https://freenginx.org/en/docs/) so I made my own repo.

# Enhancements
- Support for H3/QUIC
- [Brotli compression](https://github.com/google/ngx_brotli)
- [Zstandard compression](https://github.com/HanadaLee/ngx_http_zstd_module)
- [GeoIP2](https://github.com/leev/ngx_http_geoip2_module)
- [Headers-More](https://github.com/openresty/headers-more-nginx-module)
- Quantum cryptography
- KTLS
- debug

# Dependencies
There are quite a few dependencies to install. The main ones being:
- build-essential
- git
- curl
- wget
- cmake
- [libmaxminddb](https://github.com/maxmind/libmaxminddb)
- And probably others...

# Additional Packages
- [PCRE2](https://github.com/PCRE2Project/pcre2/)
- [zlib](https://www.zlib.net/)
- [openssl](https://github.com/openssl/openssl/)

# How to download
Please use the provided script `freenginx.sh`. Make sure to make it executable first `sudo chmod +x freenginx.sh`. Then run it with `./freenginx.sh`.

By default only the build steps are printed and all output goes to a log file in the build root. Options:
- `-v` stream all build output (still logged), `-q` print only errors and the final summary
- `-r DIR` build root, `-j N` parallel jobs, `-l FILE` log file, `-c` run `make clean` first
- `--no-brotli`, `--no-zstd`, `--no-geoip2`, `--no-headers`, `--no-ktls`, `--no-debug`
- `--asm` build OpenSSL with its assembly optimizations (AES-NI etc.); the default is `no-asm`
- Versions can be set from the environment: `V_NGINX=1.31.6 V_QSSL=3.6.5 ./freenginx.sh`

If a step fails, the script stops and prints the end of the log.

# Make a backup of your existing binary
Type `which nginx` and make a copy i.e. `sudo cp /usr/sbin/nginx /usr/sbin/nginx_apt`. **NOTE**: if you have *not* installed nginx, you do not have to do this step. **NOTE**: this script for freenginx is built as a drop in replacement for nginx.

# Install newly compiled binary
1. `cd /path/to/buildroot/nginx-release-1.29.4`
2. `sudo make install`
3. Check nginx `sudo nginx -t`
4. Reload nginx `sudo nginx -s reload`
5. Verify new version `sudo nginx -v` should output `nginx version: freenginx/1.31.6 (w/GeoIP2,Brotli,Zstd,H3,Headers-More,Quantum,debug,KTLS)`
6. Optionally free up disk space with `./freenginx.sh --purge` (same `-r` and versions as the build). It refuses to run if the built binary doesn't match `/usr/sbin/nginx`.
