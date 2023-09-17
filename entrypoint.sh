#!/bin/sh

if [ "z$BIND_KEY_ALG" = 'z' ]; then
  export BIND_KEY_ALG='hmac-sha256'
fi

if [ "$1" = 'tsig' ]; then
  # generate tsig key and expose variables
  export SECRET_KEY="$(/usr/sbin/tsig-keygen -a $BIND_KEY_ALG externaldns-key | /usr/bin/awk -F'"' '/secret/{print $2}' | /bin/base64)"
  export SECRET_NAME="${2:-bind-tsig}"
  export SECRET_NAMESPACE="$3"

  # render manifest to stdout
  /usr/bin/envsubst < /templates/secret.yaml | /bin/sed '/namespace: $/d'

  exit 0
fi

# check if key is defined
if [ "z$BIND_KEY" = 'z' ]; then
  echo 'key not defined'
  exit 1
fi

# check if zone is defined
if [ "z$BIND_ZONE" = 'z' ]; then
  echo 'zone not defined'
  exit 1
fi

# define substitution values
export ZONE_SERIAL="$(/bin/date +%s)"
export ZONE_NS_IP="$(/bin/hostname -i)"

# render config files
/usr/bin/envsubst < /templates/named.conf > /etc/bind/named.conf
/usr/bin/envsubst < /templates/zone.db > /etc/bind/zone.db

# validate config
named-checkconf /etc/bind/named.conf

# dump version info and run named
/usr/sbin/named -v
exec /usr/sbin/named -4 -f -c /etc/bind/named.conf
