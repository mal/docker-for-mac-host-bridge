# Docker for Mac - Host Bridge

As of the time of writing Docker for Mac can't access containers via IP from
the host. Let's fix that.

It's worth remembering that this appears to be a commonly requested feature, so
it might be [worth checking][docker-for-mac-networking] to see if it's been
fixed in recent versions.

Docker Version                  | Host Bridge Version | Fully Tested
------------------------------- | ------------------- | ------------------
`17.03.1-ce, build c6d412e`     | `>= 1.0.0`          | :heavy_check_mark:
`17.04.0-ce-rc2, build 2f35d73` | `>= 1.1.0`          | :heavy_check_mark:
`17.05 *`                       | `>= 1.1.0`          | :heavy_check_mark:
`17.06 *`                       | `>= 1.1.0`          | :heavy_check_mark:
`17.09.0-ce-mac33 (19543)`      | `>= 1.1.0`          | :heavy_check_mark:
`18.03.0-ce-rc1, build c160c73` | `>= 1.2.0`          | :heavy_check_mark:

[docker-for-mac-networking]: https://docs.docker.com/docker-for-mac/networking/

## Approach

Add an additional network interface (provided by `tuntap` OSX) to `moby` (the
VM containing the Linux kernel and Docker daemon) that's also accessible to the
`host`. Create a docker bridge network and then, inside `moby`, add the `tap`
backed interface to the network's bridge thus providing direct conectivity to
the `host`.

## Install

1. Download the [`tuntap` OSX][tto] kernel extensions
2. Extract the `.pkg` file within the `tuntap` archive
3. Download [`install.sh`][install]
4. (Optional, but encouraged) Read `install.sh`!
5. Run `install.sh` (see example below)

_n.b. There are several environment variable [settings][envvars]._

```sh
# DOCKER_TAP_NETWORK=acme ./install.sh tuntap_20150118.pkg
Install tuntap kernel extension
Password: ***************
installer: Package name is TunTap Installer package
installer: Upgrading at base path /
installer: The upgrade was successful.
Ensure tap extension is loaded
Permit non-root usage of tap1 device
Move original com.docker.hyperkit
Install com.docker.hyperkit shim
>>>>>>> RESTART DOCKER NOW <<<<<<<
When docker is responding (i.e. docker image ls), press return:
Create host-accessible network
efe009821235c9568f7ee66d882c22ce94edefa446abefb0159c392ac6024dbb
Bridge tap into docker network
Assign the network gateway IP to the tap interface

# docker container run -d --net acme --rm nginx:alpine
796c40fb6c78f769d502d21f2a339d08d2c75f545c579a41b6f4f7966e23ae1d

# docker container inspect -f '{{.NetworkSettings.Networks.acme.IPAddress}}' 796c40fb6c78
172.18.0.2

# curl -I 172.18.0.2
HTTP/1.1 200 OK
Server: nginx/1.11.12
Date: Fri, 31 Mar 2017 04:23:09 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Mon, 27 Mar 2017 19:48:13 GMT
Connection: keep-alive
ETag: "58d96c7d-264"
Accept-Ranges: bytes

# docker container stop 796c40fb6c78
796c40fb6c78
```

**WARNING:**

Unfortunately `install.sh` must currently be run after every restart of Docker.
This is because both `moby` and the `tap` interface only persist while Docker
is running. Hopefully this can be improved upon in the future.

[envvars]: /install.sh#L7-L14
[install]: /install.sh
[tto]: http://tuntaposx.sourceforge.net/

## Uninstall

There's no dedicated uninstaller, but the process is fairly simple:

1. Move `com.docker.hyperkit.real` back to `com.docker.hyperkit`
2. Reboot Docker
3. Restore the owner of the chosen `tap` device to `root`, or alternatively
4. Removal instructions for `tuntap` OSX can be found in [their FAQ][ttofaq].

[ttofaq]: http://tuntaposx.sourceforge.net/faq.xhtml

## Thanks

- **Michael Henkel** --
  Without these [forum][mhenkel1] [posts][mhenkel2] this wouldn't exist.
- **tuntaposx.sourceforge.net**
- **[@tinychaos42][tinychaos42]** and **[@idio][idio]** --
  Without whose Mac this investigation wouldn't have been possible.
- **[@muz][muz]** --
  Without whose beta testing containers wouldn't even have internet. >\_>;;

[mhenkel1]: https://forums.docker.com/t/support-tap-interface-for-direct-container-access-incl-multi-host/17835/2
[mhenkel2]: https://forums.docker.com/t/support-tap-interface-for-direct-container-access-incl-multi-host/17835/3
[tinychaos42]: https://github.com/tinychaos42
[idio]: https://github.com/idio
[muz]: https://github.com/muz
