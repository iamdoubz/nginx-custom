# nginx-custom
Iamdoubz custom nginx config for Ubuntu 22.04. I was tired of forgetting what I used to compile [nginx](https://nginx.org/en/docs/) so I made my own repo.

# Enhancements
- Support for H3/QUIC
- Brotli compression
- GeoIP (MaxMind)
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
Please use the provided script `nginx.sh`. Make sure to make it executable first `sudo chmod +x nginx.sh`. Then run it with `./nginx.sh`.

# Make a backup of your existing binary
Type `which nginx` and make a copy.

# Install newly compiled binary
1. `cd /path/to/buildroot`
2. `sudo make install`
