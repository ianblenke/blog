---
layout: post
title: "Using Boot2Docker"
date: 2014-11-04 23:13:25 -0500
date_formatted: Nov 4th, 2014
comments: true
categories: boot2docker
---

Boot2Docker command-line
------------------------

Preface: the [boot2docker README](https://github.com/boot2docker/boot2docker) is a great place to discover the below commands in more detail.

Now that we have Boot2Docker installed, we need to initialize a VM instance

    boot2docker init

This merely defines the default boot2docker VM, it does not start it. To do that, we need to bring it "up"

    boot2docker up

When run, it looks something like this:

    icbcfmbp:~ icblenke$ boot2docker up
    Waiting for VM and Docker daemon to start...
    ..........ooo
    Started.
    Writing /Users/icblenke/.boot2docker/certs/boot2docker-vm/ca.pem
    Writing /Users/icblenke/.boot2docker/certs/boot2docker-vm/cert.pem
    Writing /Users/icblenke/.boot2docker/certs/boot2docker-vm/key.pem

    To connect the Docker client to the Docker daemon, please set:
        export DOCKER_CERT_PATH=/Users/icblenke/.boot2docker/certs/boot2docker-vm
        export DOCKER_TLS_VERIFY=1
        export DOCKER_HOST=tcp://192.168.59.103:2376

    icbcfmbp:~ icblenke$

This is all fine and dandy, but that shell didn't actually source those variables. To do that we use boot2docker shellinit:

    eval $(boot2docker shellinit)

Now the shell has those variables exported for the running boot2docker VM.

The persistence of the boot2docker VM lasts only until we run a boot2docker destroy

    boot2docker destroy

After doing this, there is no longer a VM defined. We would need to go back to the boot2docker init step above and repeat.

Docker command-line
-------------------

From this point forward, we use the docker command to interact with the boot2docker VM as if we are on a linux docker host.

The docker command is just a compiled go application that makes RESTful calls to the docker daemon inside the linux VM.

    bash-3.2$ docker info
    Containers: 0
    Images: 0
    Storage Driver: aufs
     Root Dir: /mnt/sda1/var/lib/docker/aufs
      Dirs: 0
      Execution Driver: native-0.2
      Kernel Version: 3.16.4-tinycore64
      Operating System: Boot2Docker 1.3.1 (TCL 5.4); master : 9a31a68 - Fri Oct 31 03:14:34 UTC 2014
      Debug mode (server): true
      Debug mode (client): false
      Fds: 10
      Goroutines: 11
      EventsListeners: 0
      Init Path: /usr/local/bin/docker

This holds true for both OS/X and Windows. 

The boot2docker facade is just a handy wrapper to prepare the guest linux host VM for the docker daemin and local docker command-line client for your development host OS environment.

And now you have a starting point for exploring [Docker](http://docker.io)!

