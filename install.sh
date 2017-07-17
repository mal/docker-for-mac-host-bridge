#!/bin/bash -e

main() {
  appdir=/Applications/Docker.app
  libdir=$HOME/Library/Containers/com.docker.docker

  # additional ethernet intf inside moby (ethN); default: 1
  ethintf=${DOCKER_TAP_MOBY_ETH-1}
  # name of the docker network to create; default: tap
  network=${DOCKER_TAP_NETWORK-tap}
  # tap intf to use on host (/dev/X); default: tap1
  tapintf=${DOCKER_TAP_DEVICE-tap1}
  # name of the docker network's bridge intf inside moby; default: br-$tapintf
  netintf=${DOCKER_TAP_MOBY_BRIDGE-br-$tapintf}

  install_tuntap_driver $1
  chown_tap_device
  install_hyperkit_shim
  create_docker_network
  bridge_docker_network
  assign_ip_to_tap_intf
}

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
  set -- \
    $appdir/Contents/MacOS/com.docker.hyperkit \
    $appdir/Contents/Resources/bin/hyperkit

  for hyperkit in "$@"
    do test -f $hyperkit && break
  done

  pushd ${hyperkit%/*} > /dev/null
  binary=${hyperkit##*/}
  file $binary | grep -q text && return # already done

  log Move original $binary
  mv $binary $binary.real

  log Install $binary shim
  cat > $binary <<-EOF
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

		set -- \\
		  "\${@:1:\$start}" \\
		  "-s" "2:$ethintf,virtio-tap,$tapintf" \\
		  "\${@:\$stop}"

		exec \$0.real "\$@"
	EOF
  chmod +x $binary

  exc '>>>>>>> RESTART DOCKER NOW <<<<<<<'
  read -p 'When docker is responding (i.e. docker image ls), press return: '
  popd > /dev/null
}

create_docker_network() {
  local driver=$(docker network inspect -f '{{.Driver}}' $network 2> /dev/null)
  case "$driver" in
    '') ;;
    bridge) return ;; # already done
    *) err "Network $network does not use the bridge driver!" ;;
  esac

  log Create host-accessible network
  docker network create $network
}

bridge_docker_network() {
  log Bridge tap into docker network
  echo brctl addif $(
    docker network inspect -f '
      {{if index .Options "com.docker.network.bridge.name"}}
        {{index .Options "com.docker.network.bridge.name"}}
      {{else}}
        {{.Id | printf "br-%.12s"}}
      {{end}}
    ' $network
  ) eth$ethintf \
  > $libdir/Data/com.docker.driver.amd64-linux/tty
}

assign_ip_to_tap_intf() {
  log Assign the network gateway IP to the tap interface
  sudo ifconfig $tapintf $(
    docker network inspect -f '{{(index .IPAM.Config 0).Gateway}}' $network
  ) up
}

main "$@"
