#!/bin/bash
set -euo pipefail

function main {
    # Set Certbot Domains
    : ${CERTBOT_DOMAINS[0]:=}

    # Set Certbot Mail
    : ${CERTBOT_MAIL:=}

    # Set Certbot Webroot Path
    : ${CERTBOT_WEBROOT_PATH:=}

    # Set Certbot Pre Hook
    : ${CERTBOT_PRE_HOOK:=}

    # Set Certbot Post Hook
    : ${CERTBOT_POST_HOOK:=}

    # Set Certbot Renew Hook
    : ${CERTBOT_RENEW_HOOK:=}

    # Get Options
    if [ "$1" != "supervisord" ]; then
        args=$(getopt -n "$(basename $0)" -o d:hm:w: --long help,dry-run,pre-hook:,post-hook:,renew-hook:,version -- "$@")
        eval set --"$args"
        while true; do
            case "$1" in
                -d | --domains )
                    CERTBOT_DOMAINS[${#CERTBOT_DOMAINS[@]}]="$2"
                    shift 2
                    ;;
                -m | --email )
                    CERTBOT_MAIL="$2"
                    shift 2
                    ;;
                -w | --webroot-path )
                    CERTBOT_WEBROOT_PATH="$2"
                    shift 2
                    ;;
                --pre-hook )
                    CERTBOT_PRE_HOOK="$2"
                    shift 2
                    ;;
                --post-hook )
                    CERTBOT_POST_HOOK="$2"
                    shift 2
                    ;;
                --renew-hook )
                    CERTBOT_RENEW_HOOK="$2"
                    shift 2
                    ;;
                -h | --help )
                    print_usage;
                    shift
                    ;;
                --version )
                    print_version;
                    shift
                    ;;
                --) shift ; break ;;
                * ) break ;;
            esac
        done
        shift $((OPTIND-1))
        for arg; do
            if [ "$arg" != "letsencrypt" -a "$arg" != "certbot" ]; then
                CERTBOT_DOMAINS[${#CERTBOT_DOMAINS[@]}]="$arg"
            fi
        done
    fi

    # Certbot Cronjob Configuration
    ARGS="-q renew"

    if [ ! -z "${CERTBOT_PRE_HOOK}" ]; then
        ARGS="${ARGS} --pre-hook '${CERTBOT_PRE_HOOK}'"
    fi

    if [ ! -z "${CERTBOT_POST_HOOK}" ]; then
        ARGS="${ARGS} --post-hook '${CERTBOT_POST_HOOK}'"
    fi

    if [ ! -z "${CERTBOT_RENEW_HOOK}" ]; then
        ARGS="${ARGS} --renew-hook '${CERTBOT_RENEW_HOOK}'"
    fi

    if [ ! -z ${CERTBOT_WEBROOT} ]; then
        ARGS="${ARGS} --webroot --webroot-path ${CERTBOT_WEBROOT////\\/}"
    fi

    sed -i "s/certbot -q renew/certbot ${ARGS}/" /etc/cron.d/certbot

    # Certbot Domain Registration
    for DOMAINS in ${CERTBOT_DOMAINS[@]}; do
        ARGS="certonly --agree-tos --non-interactive"

        if [ ! -z "${CERTBOT_MAIL}" ]; then
            ARGS="${ARGS} --email ${CERTBOT_MAIL}"
        else
            ARGS="${ARGS} --register-unsafely-without-email"
        fi

        if [ ! -z ${CERTBOT_WEBROOT} ]; then
            ARGS="${ARGS} --webroot --webroot-path ${CERTBOT_WEBROOT}"
        fi

        DOMAIN=$(echo ${DOMAINS//:/ } | awk '{print $1}');

        if [ ! -d /etc/letsencrypt/live/$DOMAIN -a ! -f /etc/letsencrypt/renewal/$DOMAIN.conf ]; then
            for DOMAINS in ${DOMAINS//:/ }; do
                ARGS="$ARGS -d $DOMAINS"
            done
            certbot ${ARGS}
        fi
    done

    # Exim4 Configuration
    sed -i -e "s/dc_eximconfig_configtype=.*/dc_eximconfig_configtype='internet'/" /etc/exim4/update-exim4.conf.conf
    sed -i -e "s/dc_other_hostnames=.*/dc_other_hostnames='$(hostname --fqdn)'/" /etc/exim4/update-exim4.conf.conf
    sed -i -e "s/dc_local_interfaces=.*/dc_local_interfaces='127.0.0.1'/" /etc/exim4/update-exim4.conf.conf

    echo $(hostname) > /etc/mailname

    update-exim4.conf

    # Supervisord Configuration
    sed -i 's/^\(\[supervisord\]\)$/\1\nnodaemon=true\nuser=root\nloglevel=error/' /etc/supervisor/supervisord.conf

    sed -i 's/^\(\[unix_http_server\]\)$/\1\nusername = admin\npassword = password/' /etc/supervisor/supervisord.conf

    echo -e "[program:cron]" > /etc/supervisor/conf.d/cron.conf
    echo -e "command=/usr/sbin/cron -f" >> /etc/supervisor/conf.d/cron.conf
    echo -e "autostart=true" >> /etc/supervisor/conf.d/cron.conf
    echo -e "autorestart=true" >> /etc/supervisor/conf.d/cron.conf
    echo -e "stdout_logfile=/dev/stdout" >> /etc/supervisor/conf.d/cron.conf
    echo -e "stdout_logfile_maxbytes=0" >> /etc/supervisor/conf.d/cron.conf
    echo -e "stderr_logfile=/dev/stderr" >> /etc/supervisor/conf.d/cron.conf
    echo -e "stderr_logfile_maxbytes=0" >> /etc/supervisor/conf.d/cron.conf

    echo -e "[program:exim4]" > /etc/supervisor/conf.d/exim4.conf
    echo -e "command=/usr/sbin/exim4 -bd -v" >> /etc/supervisor/conf.d/exim4.conf
    echo -e "autostart=true" >> /etc/supervisor/conf.d/exim4.conf
    echo -e "autorestart=true" >> /etc/supervisor/conf.d/exim4.conf
    echo -e "stdout_logfile=/dev/stdout" >> /etc/supervisor/conf.d/exim4.conf
    echo -e "stdout_logfile_maxbytes=0" >> /etc/supervisor/conf.d/exim4.conf
    echo -e "stderr_logfile=/dev/stderr" >> /etc/supervisor/conf.d/exim4.conf
    echo -e "stderr_logfile_maxbytes=0" >> /etc/supervisor/conf.d/exim4.conf

    exec supervisord -c /etc/supervisor/supervisord.conf
}

function print_usage {
cat << EOF
Usage: "$(basename $0)" [Options]... [Vhosts]...

  -m EMAIL, --email EMAIL
                        Email used for registration and recovery contact.
                        (default: Ask)

  --pre-hook PRE_HOOK   Command to be run in a shell before obtaining any
                        certificates. Intended primarily for renewal, where it
                        can be used to temporarily shut down a webserver that
                        might conflict with the standalone plugin. This will
                        only be called if a certificate is actually to be
                        obtained/renewed. When renewing several certificates
                        that have identical pre-hooks, only the first will be
                        executed. (default: None)
  --post-hook POST_HOOK
                        Command to be run in a shell after attempting to
                        obtain/renew certificates. Can be used to deploy
                        renewed certificates, or to restart any servers that
                        were stopped by --pre-hook. This is only run if an
                        attempt was made to obtain/renew a certificate. If
                        multiple renewed certificates have identical post-
                        hooks, only one will be run. (default: None)
  --renew-hook RENEW_HOOK
                        Command to be run in a shell once for each
                        successfully renewed certificate. For this command,
                        the shell variable $RENEWED_LINEAGE will point to the
                        config live subdirectory containing the new certs and
                        keys; the shell variable $RENEWED_DOMAINS will contain
                        a space-delimited list of renewed cert domains
                        (default: None)

  --webroot-path WEBROOT_PATH, -w WEBROOT_PATH
                        public_html / webroot path. This can be specified
                        multiple times to handle different domains; each
                        domain will have the webroot path that preceded it.
                        For instance: `-w /var/www/example -d example.com -d
                        www.example.com -w /var/www/thing -d thing.net -d
                        m.thing.net` (default: Ask)

  -h  --help     display this help and exit

      --version  output version information and exit

E-mail bug reports to: <developer@wilke.systems>.
EOF
exit
}

function print_version {
cat << EOF

MIT License

Copyright (c) 2019 Wilke.Systems

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

EOF
exit
}

main "$@"
