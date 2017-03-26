# Docker for Mac - Host Bridge

As of the time of writing Docker for Mac can't access containers via IP from
the host. Let's fix that.

It's worth remembering that this appears to be a commonly requested feature, so
it might be [worth checking][docker-for-mac-networking] to see if it's been
fixed in recent versions.

This solution was most recently tested with: `17.03.0-ce, build 60ccb22`

[docker-for-mac-networking]: https://docs.docker.com/docker-for-mac/networking/

## Approach

Add an additional network interface (provided by `tuntaposx`) to `moby` (the VM
containing the Linux kernel and Docker daemon) that's also accessible to the
`host`. Use the `macvlan` docker network type to attach containers to the new
interface thus providing direct conectivity to the `host`.

## Guide

This is a quick overview of the steps involved in making containers accessible
to the host. Keep scrolling for a script to automate the process!

1. Install [`tuntap` OSX][tto] driver
2. Make the local user own `/dev/tap1` - prevents needing to run Docker as root
3. Move `com.docker.hyperkit` to `com.docker.hyperkit.real` in the Docker app
4. Install `com.docker.hyperkit` [shim][shim] to manipulate arguments
5. Restart Docker
6. Create a `macvlan` network with `eth1` as the parent
7. Register the host of the `tap` interface

**WARNING:**

Unfortunately step 7 must currently be performed after every restart of Docker.
This is because the `tap` interface only persists while Docker is running. The
install script can be run again to do this safely. Hopefully this aspect can be
improved upon.

[tto]: http://tuntaposx.sourceforge.net/
[shim]: /install.sh#L38-L57

## Install

A script to perform most of the steps above can be found [here][script].
Unfortunately the warning regarding step seven still applies.

There are several customisable [options][opts] which are managed by environment
variables. The most noteable of which is `DOCKER_TAP_NETWORK` which names the
network to be created. It defaults to `tap`.

[script]: /install.sh
[opts]: /install.sh#L83-L88

## Uninstall

There's no dedicated uninstaller, but the process is fairly simple:

1. Move `com.docker.hyperkit.real` back to `com.docker.hyperkit`
2. Reboot Docker
3. Change the owner of the chosen `tap` device to `root`, or alternatively
4. Removal instructions for tuntaposx can be found in [their FAQ][ttofaq].

[ttofaq]: http://tuntaposx.sourceforge.net/faq.xhtml

## Known Limitations

- Ignored port mappings - due to usage of a `macvlan` network

## Thanks

- **Michael Henkel** --
  Without these [forum][mhenkel1] [posts][mhenkel2] this wouldn't exist.
- **tuntaposx.sourceforge.net**

[mhenkel1]: https://forums.docker.com/t/support-tap-interface-for-direct-container-access-incl-multi-host/17835/2
[mhenkel2]: https://forums.docker.com/t/support-tap-interface-for-direct-container-access-incl-multi-host/17835/3
