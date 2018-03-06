#!/bin/sh
######################################################################
# Pico CA : The script of very small Certification Authority.
# Copyright (C) 2014-2016 KAMOME Engineering, Inc. All Rights Reserved.
#               This program is distributed under the MIT license.

KEYLEN=2048
CA_CERT=ca.crt
CA_KEY=ca.key
CA_CN="KAMOME PicoCA `date +%Y%m%d%H%M%S`"

########################################
# Usage

function usage() {
    echo "Pico CA : The script of very small Certification Authority."
    echo "version: 0.9.2"
    echo "usage: $0 <command>"
    echo "command list"
    echo "    destroy       : Destroys the current CA."
    echo "    create        : Creates CA."
    echo "    server <fqdn> : Make server certificate."
    echo "    client <cn>   : Make client certificate."
}

########################################
# Check existence of CA

function check_ca() {
    if [ \! -e $CA_CERT ]; then
        echo "$CA_CERT: No such file or directory"
        return 1
    fi
    if [ \! -e $CA_KAY ]; then
        echo "$CA_KEY: No such file or directory"
        return 1
    fi
}

########################################
# CA certificate

function ca_cert() {
    openssl req -new -batch -x509 -days 3650 -nodes -newkey rsa:$KEYLEN -out $CA_CERT -keyout $CA_KEY -extensions v3_ca -subj /CN="$CA_CN" || exit
    chmod 600 $CA_KEY
    openssl dhparam -out dh.pem $KEYLEN || exit
}

########################################
# Server certificate

function server_cert() {
    if [ -z "$1" ]; then
        usage;
        exit 255
    fi

    getent hosts "$1" > /dev/null
    case "$?" in
    0)
        openssl req -new -batch -nodes -newkey rsa:$KEYLEN -keyout $1.key -out $1.csr -subj /CN="$1" || exit
        chmod 600 $1.key
        openssl x509 -days 3650 -req -CA $CA_CERT -CAkey $CA_KEY -set_serial $TIMESTAMP -in $1.csr -out $1.crt || exit
        ;;
    1)
        exit 1
        ;;
    2)
        echo "$1: Host not found"
        exit 2
        ;;
    *)
        exit $?
        ;;
    esac
}

########################################
# Client certificate

function client_cert() {
    if [ -z "$1" ]; then
        usage;
        exit 255
    fi

    f=`echo "$1" | sed -e 's/[ 	]/_/g' | sed -e 's/[\/:]/-/g'`
    openssl req -new -batch -nodes -newkey rsa:$KEYLEN -keyout $f.key -out $f.csr -extensions usr_cert -subj /CN="$1" || exit
    chmod 600 $f.key
    openssl x509 -days 3650 -req -CA $CA_CERT -CAkey $CA_KEY -set_serial $TIMESTAMP -in $f.csr -out $f.crt || exit
}

########################################
# Pico Certificate Authority

TIMESTAMP="`date +%Y%m%d%H%M%S`"

if [ $# -lt 1 ]; then
    usage;
    exit 255
fi

case "$1" in
create)
    if [ -e $CA_CERT ]; then
        echo "$CA_CERT: File exists"
        exit 255
    fi
    if [ -e $CA_KEY ]; then
        echo "$CA_KEY: File exists"
        exit 255
    fi
    ca_cert || exit
    ;;
server)
    check_ca || exit
    server_cert "$2" || exit
    ;;
client)
    check_ca || exit
    client_cert "$2" || exit
    ;;
destroy)
    # Destroy CA which exists in a current directory?
    rm -i $CA_CERT $CA_KEY
    if [ \! -e $CA_CERT -o \! -e $CA_KEY ]; then
        rm -f *.key *.csr *.crt
    fi
    ;;
*)
    usage;
    exit 255
    ;;
esac

