Cozy Dockerfile
===============

## ⚠️ DEPRECATION WARNING ⚠️ **

This was an experimental image for the old version of Cozy, based on Node.js. Both this version and this image are now deprecated and unmaintained. Some work has been done to create an [image for the new, Go based, Cozy V3](https://github.com/cozy/gozy-docker), but this is still a work in progress.

---

This is the Dockerfile recipe used to build the official Cozy image.
It is built on top of the Ubuntu 14.04 image.

## Installation

* Install [Docker](https://www.docker.com/). This recipe has been tested on **Docker v1.0.1 and newer**.
* Fetch the Cozy image:
```
sudo docker pull cozy/full
```

* OR you can build the container manually by running:
```bash
sudo docker build -t cozy/full github.com/cozy-labs/cozy-docker
```

## Usage

```
sudo docker run -d -p 80:80 -p 443:443 cozy/full
```

Where `-d` tells Docker to daemonize the process and `-p` to bind ports to the host.

Then, you can open https://localhost/ in your browser to start using your new
dockerized cozy instance.


## Usage as a development environment

You can also use the same Docker image as a development environment. To do so, just add `-e NODE_ENV=development` and `-e DISABLE_SSL=true`:

```
sudo docker run -e NODE_ENV=development -e DISABLE_SSL=true -d -p 80:80 cozy/full
```


## Hack

In order to modify or patch this recipe you have to clone the repository:
```bash
git clone https://github.com/cozy-labs/cozy-docker
cd cozy-docker
```

Modify the Dockerfile and/or the configuration files then build the container:
```bash
sudo docker build -t cozy/full .
```

That's all!


## Security

It is highly recommended to build the image locally if you want to run Cozy in a production environment:
```
sudo docker build -t cozy github.com/cozy-labs/cozy-docker
```

This way, the security tokens will be reset, and the SSL certificate will be renewed.



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
