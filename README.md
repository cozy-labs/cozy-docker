Cozy Dockerfile
===============

This is the Dockerfile recipe used to build the official Cozy image.
It is built on top of the Ubuntu 14.04 image.

## Installation

1. Install [Docker](https://www.docker.com/). This recipe has been tested on **Docker v1.0.1 and newer**.
2. Fetch the Cozy image: `sudo docker pull cozy/full`
3. You can alternatively build the container manually:
```bash
sudo docker build -t cozy github.com/cozy-labs/cozy-docker
```

## Usage

```
docker run -d -p 80:80 -p 443:443 cozy
```

Where `-d` tells Docker to daemonize the process and `-p` to bind ports to the host.


## Hack

In order to modify or patch this recipe you have to clone the repository:
```bash
git clone https://github.com/cozy-labs/cozy-docker
cd cozy-docker
```

Modify the Dockerfile and/or the configuration files then build the container:
```bash
sudo docker build -t cozy .
```

That's all!


## What is Cozy?

![Cozy Logo](https://raw.github.com/mycozycloud/cozy-setup/gh-pages/assets/images/happycloud.png)

[Cozy](http://cozy.io) is a platform that brings all your web services in the
same private space.  With it, your web apps and your devices can share data
easily, providing you
with a new experience. You can install Cozy on your own hardware where no one
profiles you.


## Community

You can reach the Cozy Community by:

* Chatting with us on IRC #cozycloud on irc.freenode.net
* Posting on our [Forum](https://forum.cozy.io)
* Posting issues on the [Github repos](https://github.com/mycozycloud/)
* Mentioning us on [Twitter](http://twitter.com/mycozycloud)
