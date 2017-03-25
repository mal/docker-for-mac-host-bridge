#!/bin/bash -e

err() { echo "$(tput setaf 9)$@$(tput sgr0)"; exit 1; }
exc() { echo "$(tput setaf 11)$@$(tput sgr0)"; }
log() { echo "$(tput setaf 10)$@$(tput sgr0)"; }

install_tuntap_driver() {
  test -c /dev/$tapintf && return # already done

  test $# -lt 1 && err "
    Expecting tuntap .pkg file as first arg
    Get it here: http://tuntaposx.sourceforge.net/
  "

  log Install tuntap kernel extension
  sudo installer -package $1 -target /

  log Ensure tap extension is loaded
  sudo kextload /Library/Extensions/tap.kext
}

chown_tap_device() {
  test "$(stat -f %Su /dev/$tapintf)" = "$USER" && return # already done

  log Permit non-root usage of $tapintf device
  sudo chown $USER /dev/$tapintf
}

install_hyperkit_shim() {
  cd /Applications/Docker.app/Contents/MacOS/
  file com.docker.hyperkit | grep -q text && return # already done

  log Move original com.docker.hyperkit
  mv com.docker.hyperkit com.docker.hyperkit.real

  log Install com.docker.hyperkit shim
  cat > com.docker.hyperkit <<-EOF
		#!/bin/bash

		start=0

		for arg in "\$@"
		  do if echo "\$arg" | grep -F 'virtio-vpnkit'
		    then break
		    else start=\$((\$start + 1))
		  fi
		done

		start=\$((\$start + 1))
		stop=\$((\$start + 1))

		set -- \
		  "\${@:1:\$start}" \
		  "-s" "2:$mobyintf,virtio-tap,$tapintf" \
		  "\${@:\$stop}"

		exec \$0.real "\$@"
	EOF
  chmod +x com.docker.hyperkit

  exc '>>>>>>> RESTART DOCKER NOW <<<<<<<'
  read -p 'When docker is responding (i.e. docker image ls), press return: '
}

create_docker_network() {
  if docker network inspect -f . $network > /dev/null 2>&1; then
    exc "Network $network exists!"
    exc "It should use the macvlan driver and eth$mobyintf as it's parent."
    return
  fi

  log Create host-accessible network
  docker network create -d macvlan -o parent=eth$mobyintf $network
}

assign_ip_to_tap_intf() {
  log Assign the network gateway IP to the tap interface
  sudo ifconfig $tapintf $(
    docker network inspect -f '{{(index .IPAM.Config 0).Gateway}}' $network
  ) up
}

# id of extra eth intf inside moby (ethN); default: 1
mobyintf=${DOCKER_MOBY_TAP_INTERFACE_ID-1}
# name of the host-accessible docker network to create; default: tap
network=${DOCKER_TAP_NETWORK-tap}
# tap device to use (/dev/X); default: tap1
tapintf=${DOCKER_TAP_INTERFACE-tap1}

install_tuntap_driver $1
chown_tap_device
install_hyperkit_shim
create_docker_network
assign_ip_to_tap_intf
