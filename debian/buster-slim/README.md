# Supported tags and respective `Dockerfile` links

-	[`latest` (*/debian/stretch-slim/Dockerfile*)](https://github.com/wilkesystems/docker-certbot/blob/master/debian/stretch-slim/Dockerfile)

# Certbot on Debian Buster
This certbot image contains almost all nginx nice modules using `certbot` package.

## Get Image
[Docker hub](https://hub.docker.com/r/wilkesystems/certbot)

```bash
docker pull wilkesystems/certbot
```

## How to use this image

```bash
$ docker run -d --name certbot \
    -e CERTBOT_POST_HOOK='docker nginx restart' \
    -e CERTBOT_WEBROOT_PATH=/var/www/html \
    -v /path/to/certs:/etc/letsencrypt \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v /var/www/html:/var/www/html \
    wilkesystems/certbot \
    example.org:www.example.org
```

# Environment

- `-e CERTBOT_MAIL=...` Set the registration E-Mail
- `-e CERTBOT_PRE_HOOK=...` Command to be run in a shell before obtaining any certificates
- `-e CERTBOT_POST_HOOK=...` Command to be run in a shell after attempting to obtain/renew certificates
- `-e CERTBOT_RENEW_HOOK=...` Command to be run in a shell once for each successfully renewed certificate
- `-e CERTBOT_WEBROOT_PATH=...` Obtain certs by placing files in a webroot directory

## Auto Builds
New images are automatically built by each new library/debian push.

## Package: certbot
Package: [certbot](https://packages.debian.org/stretch/certbot)

The objective of Certbot, Let's Encrypt, and the ACME (Automated Certificate Management Environment) protocol is to make it possible to set up an HTTPS server and have it automatically obtain a browser-trusted certificate, without any human intervention. This is accomplished by running a certificate management agent on the web server. 

This agent is used to: 

  - Automatically prove to the Let's Encrypt CA that you control the website
  - Obtain a browser-trusted certificate and set it up on your web server
  - Keep track of when your certificate is going to expire, and renew it
  - Help you revoke the certificate if that ever becomes necessary.

This package contains the main application, including the standalone and the manual authenticators. 
