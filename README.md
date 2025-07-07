# nginx-custom
Iamdoubz custom nginx config for Ubuntu 22.04. I was tired of forgetting what I used to compile [nginx](https://nginx.org/en/docs/) so I made my own repo.

# Enhancements
- Support for H3/QUIC
- [Brotli compression](https://github.com/google/ngx_brotli)
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
Please use the provided script `nginx.sh`. Make sure to make it executable first `sudo chmod +x nginx.sh`. Then run it with `./nginx.sh`.
If you want to use quantum enabled cryptogaphy, use script `nginxq.sh`.

# Make a backup of your existing binary
Type `which nginx` and make a copy i.e. `sudo cp /usr/sbin/nginx /usr/sbin/nginx_apt`. **NOTE**: if you have *not* installed nginx, you do not have to do this step.

# Install newly compiled binary
1. `cd /path/to/buildroot/nginx-1.29.0`
2. `sudo make install`
3. Check nginx `sudo nginx -t`
4. Reload nginx `sudo nginx -s reload`
5. Verify new version `sudo nginx -v` should output `nginx version: nginx/1.29.0 (w/GeoIP2,Brotli,H3,Headers-More,Quantum,debug,KTLS)`

# Windows
I have pre-compiled both branches for Windows. If you would like to download them, follow the link to my personal Gitea site, and navigate to the "Releases" page.
