#!/usr/bin/env bash

# Don't run directly. Should be sourced by init-gateway.sh
echo
echo "--- Creating configuration files ---"
echo

cat <<EOF >/etc/vpn-ios-or-mac.mobileconfig
<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE plist PUBLIC '-//Apple//DTD PLIST 1.0//EN' 'http://www.apple.com/DTDs/PropertyList-1.0.dtd'>
<plist version='1.0'>
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>IKEv2</key>
      <dict>
        <key>AuthenticationMethod</key>
        <string>None</string>
        <key>ChildSecurityAssociationParameters</key>
        <dict>
          <key>EncryptionAlgorithm</key>
          <string>AES-256-GCM</string>
          <key>IntegrityAlgorithm</key>
          <string>SHA2-384</string>
          <key>DiffieHellmanGroup</key>
          <integer>21</integer>
          <key>LifeTimeInMinutes</key>
          <integer>1440</integer>
        </dict>
        <key>DeadPeerDetectionRate</key>
        <string>Medium</string>
        <key>DisableMOBIKE</key>
        <integer>0</integer>
        <key>DisableRedirect</key>
        <integer>0</integer>
        <key>EnableCertificateRevocationCheck</key>
        <integer>0</integer>
        <key>EnablePFS</key>
        <true/>
        <key>ExtendedAuthEnabled</key>
        <true/>
        <key>IKESecurityAssociationParameters</key>
        <dict>
          <key>EncryptionAlgorithm</key>
          <string>AES-256-GCM</string>
          <key>IntegrityAlgorithm</key>
          <string>SHA2-384</string>
          <key>DiffieHellmanGroup</key>
          <integer>21</integer>
          <key>LifeTimeInMinutes</key>
          <integer>1440</integer>
        </dict>
        <key>OnDemandEnabled</key>
        <integer>1</integer>
        <key>OnDemandRules</key>
        <array>
          <dict>
            <key>Action</key>
            <string>Connect</string>
          </dict>
        </array>
        <key>RemoteAddress</key>
        <string>${VPNHOST}</string>
        <key>RemoteIdentifier</key>
        <string>${VPNHOST}</string>
        <key>UseConfigurationAttributeInternalIPSubnet</key>
        <integer>0</integer>
      </dict>
      <key>IPv4</key>
      <dict>
        <key>OverridePrimary</key>
        <integer>1</integer>
      </dict>
      <key>PayloadDescription</key>
      <string>Configures VPN settings</string>
      <key>PayloadDisplayName</key>
      <string>VPN</string>
      <key>PayloadIdentifier</key>
      <string>com.apple.vpn.managed.$(uuidgen)</string>
      <key>PayloadType</key>
      <string>com.apple.vpn.managed</string>
      <key>PayloadUUID</key>
      <string>$(uuidgen)</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>Proxies</key>
      <dict>
        <key>HTTPEnable</key>
        <integer>0</integer>
        <key>HTTPSEnable</key>
        <integer>0</integer>
      </dict>
      <key>UserDefinedName</key>
      <string>${VPNHOST}</string>
      <key>VPNType</key>
      <string>IKEv2</string>
    </dict>
  </array>
  <key>PayloadDisplayName</key>
  <string>IKEv2 VPN configuration (${VPNHOST})</string>
  <key>PayloadIdentifier</key>
  <string>com.mackerron.vpn.$(uuidgen)</string>
  <key>PayloadRemovalDisallowed</key>
  <false/>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string>$(uuidgen)</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>
EOF

cat <<EOF >/etc/vpn-ubuntu-client.sh
#!/bin/bash -e
if [[ \$(id -u) -ne 0 ]]; then echo "Please run as root (e.g. sudo ./path/to/this/script)"; exit 1; fi

#Exit when error - first argument is the reason of the error
function exit_badly {
  echo \$1
  exit 1
}

CERT_NAME="cert.pem"

VPNUSERNAME=""
CERT_PATH=""
CA_PATH=""
SKIP_CERT=0

for ((i=1;i<=\$#;i++));
do
    if [ \${!i} = "--skip-cert" ]
    then SKIP_CERT=1

    elif [ \${!i} = "-u" ];
    then ((i++))
        VPNUSERNAME=\${!i};

    elif [ \${!i} = "-c" ];
    then ((i++))
        CERT_PATH=\${!i};

    elif [ \${!i} = "-a" ];
    then ((i++))
        CA_PATH=\${!i};

    elif [ \${!i} = "-h" ];
    then
      echo "usage with cert config: -u <username> -c <certificate_path> -a <CA_path>"
      echo "usage without cert config: -u <username> --skip-cert"
      exit 0
    fi

done;

if [ \${SKIP_CERT} = 0 ]
 then

 [ -z "\$CERT_PATH" ] && exit_badly "specify cert file using -c <certificate path>. Use -h for help"
  if [ ! -f \${CERT_PATH} ]; then
    exit_badly "specify valid cert file"
  fi

[ -z "\$CA_PATH" ] && exit_badly "specify ca cert file using -a <CA path>. Use -h for help"
  if [ ! -f \${CA_PATH} ]; then
    exit_badly "specify valid cert file"
  fi

fi

[ -z "\$VPNUSERNAME" ] && exit_badly "specify vpn username with -u <username>. Use -h for help"


while true; do
read -s -p "VPN password (same as entered on server): " VPNPASSWORD
echo
read -s -p "Confirm VPN password: " VPNPASSWORD2
echo
[ "\$VPNPASSWORD" = "\$VPNPASSWORD2" ] && break
echo "Passwords didn't match -- please try again"
done

apt-get install -y strongswan libstrongswan-standard-plugins libcharon-extra-plugins
apt-get install -y libcharon-standard-plugins || true  # 17.04+ only

ln -f -s /etc/ssl/certs/DST_Root_CA_X3.pem /etc/ipsec.d/cacerts/

if [ \${SKIP_CERT} = 0 ]
 then
 #Copy certificates
  cp -f \${CA_PATH} /etc/ipsec.d/cacerts/CA-cert.pem
  cp -f \${CERT_PATH} /etc/ipsec.d/certs/${CERT_NAME}

  grep -Fq 'bug-zero/bugzero-gateway' /etc/ipsec.conf || echo "
# https://github.com/bug-zero/bugzero-gateway
conn ikev2vpn
        ikelifetime=60m
        keylife=20m
        rekeymargin=3m
        keyingtries=1
        keyexchange=ikev2
        ike=aes256gcm16-prfsha384-ecp521!
        esp=aes256gcm16-ecp521!
        leftsourceip=%config
        leftauth=eap-mschapv2
        leftcert=\${CERT_NAME}
        eap_identity=\${VPNUSERNAME}
        right=${VPNHOST}
        rightauth=pubkey
        rightid=@${VPNHOST}
        rightsubnet=0.0.0.0/0
        auto=add  # or auto=start to bring up automatically
" >> /etc/ipsec.conf

else

grep -Fq 'bug-zero/bugzero-gateway' /etc/ipsec.conf || echo "
# https://github.com/bug-zero/bugzero-gateway
conn ikev2vpn
        ikelifetime=60m
        keylife=20m
        rekeymargin=3m
        keyingtries=1
        keyexchange=ikev2
        ike=aes256gcm16-prfsha384-ecp521!
        esp=aes256gcm16-ecp521!
        leftsourceip=%config
        leftauth=eap-mschapv2
        eap_identity=\${VPNUSERNAME}
        right=${VPNHOST}
        rightauth=pubkey
        rightid=@${VPNHOST}
        rightsubnet=0.0.0.0/0
        auto=add  # or auto=start to bring up automatically
" >> /etc/ipsec.conf

fi


grep -Fq 'bug-zero/bugzero-gateway' /etc/ipsec.secrets || echo "
# https://github.com/bug-zero/bugzero-gateway
\${VPNUSERNAME} : EAP \"\${VPNPASSWORD}\"
" >> /etc/ipsec.secrets

ipsec restart
#sleep 5  # is there a better way?

#echo "Bringing up VPN ..."
#ipsec up ikev2vpn
#ipsec statusall

#echo
#echo -n "Testing IP address ... "
#VPNIP=\$(dig -4 +short ${VPNHOST})
#ACTUALIP=\$(curl -s ifconfig.co)
#if [[ "\$VPNIP" == "\$ACTUALIP" ]]; then echo "PASSED (IP: \${VPNIP})"; else echo "FAILED (IP: \${ACTUALIP}, VPN IP: \${VPNIP})"; fi

echo
echo "To disconnect: ipsec down ikev2vpn"
echo "To resconnect: ipsec up ikev2vpn"
echo "To connect automatically: change auto=add to auto=start in /etc/ipsec.conf"
EOF

cat <<EOF >/etc/vpn-instructions.txt
== iOS and macOS ==

A configuration profile is attached as vpn-ios-or-mac.mobileconfig — simply open this to install. You will be asked for your device PIN or password, and your VPN username and password, not necessarily in that order.


== Windows ==

You will need Windows 10 Pro or above. Please run the following commands in PowerShell:

Add-VpnConnection -Name "${VPNHOST}" \`
  -ServerAddress "${VPNHOST}" \`
  -TunnelType IKEv2 \`
  -EncryptionLevel Maximum \`
  -AuthenticationMethod EAP \`
  -RememberCredential

Set-VpnConnectionIPsecConfiguration -ConnectionName "${VPNHOST}" \`
  -AuthenticationTransformConstants GCMAES256 \`
  -CipherTransformConstants GCMAES256 \`
  -EncryptionMethod GCMAES256 \`
  -IntegrityCheckMethod SHA384 \`
  -DHGroup ECP384 \`
  -PfsGroup ECP384 \`
  -Force

# Run the following command to retain access to the local network (e.g. printers, file servers) while the VPN is connected.
# On a home network, you probably want this. On a public network, you probably don't.

Set-VpnConnection -Name "${VPNHOST}" -SplitTunneling \$True


== Android ==

Download the strongSwan app from the Play Store: https://play.google.com/store/apps/details?id=org.strongswan.android

Server: ${VPNHOST}
VPN Type: IKEv2 EAP (Username/Password)
Username and password: as configured on the server
CA certificate: Select automatically


== Ubuntu ==

A bash script to set up strongSwan as a VPN client is attached as vpn-ubuntu-client.sh. You will need to chmod +x and then run the script as root.

EOF

EMAIL=$USER@$VPNHOST mutt -s "VPN configuration" -a vpn-ios-or-mac.mobileconfig vpn-ubuntu-client.sh -- $EMAILADDR <vpn-instructions.txt

echo
echo "--- How to connect ---"
echo
echo "Connection instructions have been emailed to you, and can also be found in your home directory, /home/${USER}"

# necessary for IKEv2?
# Windows: https://support.microsoft.com/en-us/kb/926179
# HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\PolicyAgent += AssumeUDPEncapsulationContextOnSendRule, DWORD = 2
