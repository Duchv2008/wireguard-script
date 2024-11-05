function newFullClients() {
	# 254
    for CLIENT_DOT_IP in {3..100}; do
        sleep 0.5
        newClient "client_$CLIENT_DOT_IP" "$CLIENT_DOT_IP"
	done
}

function getHomeDirForClient() {
	local CLIENT_NAME=$1

	if [ -z "${CLIENT_NAME}" ]; then
		echo "Error: getHomeDirForClient() requires a client name as argument"
		exit 1
	fi

	# Home directory of the user, where the client configuration will be written
	if [ -e "/home/${CLIENT_NAME}" ]; then
		# if $1 is a user name
		HOME_DIR="/home/${CLIENT_NAME}"
	elif [ "${SUDO_USER}" ]; then
		# if not, use SUDO_USER
		if [ "${SUDO_USER}" == "root" ]; then
			# If running sudo as root
			HOME_DIR="/root"
		else
			HOME_DIR="/home/${SUDO_USER}"
		fi
	else
		# if not SUDO_USER, use /root
		HOME_DIR="/root"
	fi

	echo "$HOME_DIR"
}

function newClient() {
    echo ""
	# echo "Create user start $1 $2"


	if [[ ${SERVER_PUB_IP} =~ .*:.* ]]; then
		if [[ ${SERVER_PUB_IP} != *"["* ]] || [[ ${SERVER_PUB_IP} != *"]"* ]]; then
			SERVER_PUB_IP="[${SERVER_PUB_IP}]"
		fi
	fi
	ENDPOINT="${SERVER_PUB_IP}:${SERVER_PORT}"

	CLIENT_NAME=$1
	# echo ""
	# echo "Create client $1"
	# echo ""

	until [[ ${CLIENT_NAME} =~ ^[a-zA-Z0-9_-]+$ && ${CLIENT_EXISTS} == '0' && ${#CLIENT_NAME} -lt 16 ]]; do
		CLIENT_EXISTS=$(grep -c -E "^### Client ${CLIENT_NAME}\$" "/etc/wireguard/${SERVER_WG_NIC}.conf")

		if [[ ${CLIENT_EXISTS} != 0 ]]; then
			echo ""
			echo -e "${ORANGE}A client with the specified name was already created, please choose another name.${NC}"
			echo ""
			return
		fi
	done

    DOT_IP=$2
 #    echo ""
	# echo "Create client $1 with DOT_IP ${DOT_IP} SERVER_WG_IPV4 ${SERVER_WG_IPV4} SERVER_WG_NIC ${SERVER_WG_NIC}"
	# echo ""

	DOT_EXISTS=$(grep -c "${SERVER_WG_IPV4::-1}${DOT_IP}" "/etc/wireguard/${SERVER_WG_NIC}.conf")

	if [[ ${DOT_EXISTS} == '1' ]]; then
		echo ""
		echo "The subnet configured supports only 253 clients."
		exit 1
	fi

	BASE_IP=$(echo "$SERVER_WG_IPV4" | awk -F '.' '{ print $1"."$2"."$3 }')

    local IPV4_EXISTS=""

 #    echo ""
	# echo "BASE_IP ${BASE_IP} IPV4_EXISTS ${IPV4_EXISTS}"
	# echo ""

	until [[ ${IPV4_EXISTS} == '0' ]]; do
		CLIENT_WG_IPV4="${BASE_IP}.${DOT_IP}"

        echo ""
		echo "CLIENT_WG_IPV4 $CLIENT_WG_IPV4"
        echo ""

		IPV4_EXISTS=$(grep -c "$CLIENT_WG_IPV4/32" "/etc/wireguard/${SERVER_WG_NIC}.conf")

		if [[ ${IPV4_EXISTS} != 0 ]]; then
			echo ""
			echo -e "${ORANGE}A client with the specified IPv4 was already created, please choose another IPv4.${NC}"
			echo ""
		fi
	done

 #    echo ""
	# echo "Generate BASE IP v6 ${SERVER_WG_IPV6}"
	# echo ""

	BASE_IP=$(echo "$SERVER_WG_IPV6" | awk -F '::' '{ print $1 }')

 #    echo ""
	# echo "Generate BASE IP v6 2"
	# echo ""
	local IPV6_EXISTS=""
	until [[ ${IPV6_EXISTS} == '0' ]]; do
		CLIENT_WG_IPV6="${BASE_IP}::${DOT_IP}"

		echo ""
		echo "CLIENT_WG_IPV6 $CLIENT_WG_IPV6"
        echo ""

		IPV6_EXISTS=$(grep -c "${CLIENT_WG_IPV6}/128" "/etc/wireguard/${SERVER_WG_NIC}.conf")

		if [[ ${IPV6_EXISTS} != 0 ]]; then
			echo ""
			echo -e "${ORANGE}A client with the specified IPv6 was already created, please choose another IPv6.${NC}"
			echo ""
		fi
	done

 #    echo ""
	# echo "Generate BASE IP 3"
	# echo ""

	# Generate key pair for the client
	CLIENT_PRIV_KEY=$(wg genkey)
	CLIENT_PUB_KEY=$(echo "${CLIENT_PRIV_KEY}" | wg pubkey)
	CLIENT_PRE_SHARED_KEY=$(wg genpsk)

	HOME_DIR=$(getHomeDirForClient "${CLIENT_NAME}")

 #    echo ""
	# echo "Generate BASE IP 4"
	# echo ""

	# Create client file and add the server as a peer
	echo "[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_WG_IPV4}/32,${CLIENT_WG_IPV6}/128
DNS = ${CLIENT_DNS_1},${CLIENT_DNS_2}

[Peer]
PublicKey = ${SERVER_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
Endpoint = ${ENDPOINT}
AllowedIPs = ${ALLOWED_IPS}" >"${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"

 #    echo ""
	# echo "Generate BASE IP 5"
	# echo ""

	# Add the client as a peer to the server
	echo -e "\n### Client ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
AllowedIPs = ${CLIENT_WG_IPV4}/32,${CLIENT_WG_IPV6}/128" >>"/etc/wireguard/${SERVER_WG_NIC}.conf"

 #    echo ""
	# echo "Generate BASE IP 6"
	# echo ""
	wg syncconf "${SERVER_WG_NIC}" <(wg-quick strip "${SERVER_WG_NIC}")

	# Generate QR code if qrencode is installed
# 	if command -v qrencode &>/dev/null; then
# 		echo -e "${GREEN}\nHere is your client config file as a QR Code:\n${NC}"
# 		qrencode -t ansiutf8 -l L <"${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"
# 		echo ""
# 	fi

	echo -e "${GREEN}Your client config file is in ${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf${NC}"
 #    echo "-----------------------------------------------"
	# echo ""
}

source /etc/wireguard/params
newFullClients
