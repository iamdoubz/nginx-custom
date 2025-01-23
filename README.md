# freenginx-custom
Iamdoubz custom freenginx config for Ubuntu 22.04. I was tired of forgetting what I used to compile [freenginx](https://freenginx.org/en/docs/) so I made my own repo.

# Enhancements
- Support for H3/QUIC
- Brotli compression
- GeoIP2 (MaxMind)
- debug

# Dependencies
There are quite a few dependencies to install. The main ones being:
- build-essential
- git
- curl
- wget
- [libmaxminddb](https://github.com/maxmind/libmaxminddb)
- And probably others...

# How to download
Please use the provided script `freenginx.sh`. Make sure to make it executable first `sudo chmod +x freenginx.sh`. Then run it with `./freenginx.sh`.

# Make a backup of your existing binary
Type `which nginx` and make a copy i.e. `sudo cp /usr/sbin/nginx /usr/sbin/nginx_apt`. **NOTE**: if you have *not* installed nginx, you do not have to do this step. **NOTE**: this script for freenginx is built as a drop in replacement for nginx.

# Install newly compiled binary
1. `cd /path/to/buildroot/nginx-release-1.27.4`
2. `sudo make install`
3. Check nginx `sudo nginx -t`
4. Reload nginx `sudo nginx -s reload`
5. Verify new version `sudo nginx -v` should output `nginx version: freenginx/1.27.4 (w/GeoIP2,Brotli,H3,debug)`
