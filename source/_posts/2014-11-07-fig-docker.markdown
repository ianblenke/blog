---
layout: post
title: "fig-docker'
date: 2014-11-07 19:20:06 -0500
comments: true
categories: docker fig development orchestration
---

A common devops problem when developing [Docker](http://docker.io) containers is managing the orchestration of multiple containers in a development environment.

There are a number of orchestration harnesses for Docker available:

- OrchardUp's [Fig](http://fig.sh)
- [Vagrant](https://docs.vagrantup.com/v2/provisioning/docker.html)
- [kubernetes](https://github.com/GoogleCloudPlatform/kubernetes)
- [maestro-ng](https://github.com/signalfuse/maestro-ng)
- Centurylink's [Panamax](http://panamax.io/)
- [Shipyard](http://shipyard-project.com/)
- [Decking](http://decking.io/)
- NewRelic's [Centurion](https://github.com/newrelic/centurion)
- Spotify's [Spotify's](https://github.com/spotify/helios)
- [Stampede](https://github.com/cattleio/stampede)
- [Chef](https://www.getchef.com/solutions/docker/)
- [Ansible](http://www.ansible.com/docker)
- [Flynn](https://flynn.io/)
- [Tsuru](http://tsuru.io/)
- [Flocker](https://clusterhq.com/)
- [CloudFocker](https://github.com/CloudCredo/cloudfocker)
- [CloudFoundry](http://cloudfoundry.org)'s [docker-boshrelease](https://github.com/cf-platform-eng/docker-boshrelease)/[diego](https://github.com/cloudfoundry-incubator/diego-release)
- [Deis](http://deis.io) (a PaaS that can git push deploy containers using [Heroku](http://heroku.com) buildpacks _or_ a Dockerfile)

There are also RAFT/GOSSIP clustering solutions like:

- [CoreOS](https://coreos.com/)/[Fleet](https://github.com/coreos/fleet)
- [OpenShift Origin](https://www.openshift.com/products/origin) uses [ProjectAtomic](http://www.projectatomic.io/)/[Geard](https://openshift.github.io/geard/)

My [coreos-vagrant-kitchen-sink](https://github.com/ianblenke/coreos-vagrant-kitchen-sink) github project submits [cloud-init units](https://github.com/ianblenke/coreos-vagrant-kitchen-sink/tree/master/cloud-init) via a YAML file when booting member nodes. It's a good model for production, but it's a bit heavy for development.

Docker is currently working on [Docker Clustering](https://www.youtube.com/watch?v=vtnSL79rZ6o), but it is presently just a proof-of-concept and is now under a total re-write.

They are also [implementing docker composition](https://www.youtube.com/watch?v=YuSq6bXHnOI) which provides Fig like functionality using upcoming docker "groups".

That influence of Fig makes sense, as [Docker bought Orchard](http://venturebeat.com/2014/07/22/docker-buys-orchard-a-2-man-startup-with-a-cloud-service-for-running-docker-friendly-apps/).

Internally, Docker developers use [Fig](http://fig.sh).

Docker's website also directs everyone to [Boot2Docker](http://boot2docker.io), as that is the tool Docker developers use as their docker baseline environment. 

Boot2Docker spawns a [VirtualBox](https://www.virtualbox.org/) based VM as well as a native docker client runtime on the developer's host machine, and provides the `DOCKER_HOST` and related enviroments necessary for the client to talk to the VM.

This allows a developer's Windows or OS/X machine to have a docker command that behaves as if the docker containers are running natively on their host machine.

While Fig is easy to install under OS/X as it has native Python support ("pip install fig"), installing Fig on a Windows developer workstation would normally require Python support be installed separately.

Rather than do that, I've built a new [ianblenke/fig-docker](https://registry.hub.docker.com/u/ianblenke/fig-docker/) docker Hub image, which is auto-built from [ianblenke/docker-fig-docker](https://github.com/ianblenke/docker-fig-docker) on github.

This allows running fig inside a docker container using:

    docker run -v $(pwd):/app -v $DOCKER_CERT_PATH:/certs -e DOCKER_CERT_PATH=/certs -e DOCKER_HOST=$DOCKER_HOST -e DOCKER_TLS_VERIFY=$DOCKER_TLS_VERIFY -ti --rm ianblenke/fig-docker fig --help

Alternatively, a developer can alias it:

    alias fig="docker run -v $(pwd):/app -v $DOCKER_CERT_PATH:/certs -e DOCKER_CERT_PATH=/certs -e DOCKER_HOST=$DOCKER_HOST -e DOCKER_TLS_VERIFY=$DOCKER_TLS_VERIFY -ti --rm ianblenke/fig-docker fig"

Now the developer can run `fig` as if it is running on their development host, continuing the boot2docker illusion.

In the above examples, the current directory `$(pwd)` is being mounted as /app inside the docker container.

On a boot2docker install, the boot2docker VM is the actual source of that volume path.

That means you would actually have to have the current path inside the boot2docker VM as well.

To do that, on a Mac, do this:

    boot2docker down
    VBoxManage sharedfolder add boot2docker-vm -name home -hostpath /Users
    boot2docker up

From this point forward, until the next `boot2docker init`, your boot2docker VM should have your home directory mounted as /Users and the path should be the same.

A similar trick happens for Windows hosts, providing the same path inside the boot2docker VM as a developer would use.

This allows a normalized docker/fig interface for developers to begin their foray into docker orchestration.

Let's setup a very quick [Ruby on Rails](http://rubyonrails.org/) application from scratch, and then add a Dockerfile and fig.yml that spins up a mysql service for it to talk to.

Here's a quick script that does just that. The only requirement is a functional docker command able to spin up containers.

    #!/bin/bash
    set -ex

    # Source the boot2docker environment variables
    eval $(boot2docker shellinit 2>/dev/null)

    # Use a rails container to create a new rails project in the current directory called figgypudding
    docker run -it --rm -v $(pwd):/app rails:latest bash -c 'rails new figgypudding; cp -a /figgypudding /app'

    cd figgypudding

    # Create the Dockerfile used to build the figgypudding_web:latest image used by the figgypudding_web_1 container
    cat <<EOD > Dockerfile
    FROM rails:onbuild
    ENV HOME /usr/src/app
    EOD

    # This is the Fig orchestration configuration
    cat <<EOF > fig.yml
    mysql:
      environment:
        MYSQL_ROOT_PASSWORD: supersecret
        MYSQL_DATABASE: figgydata
        MYSQL_USER: figgyuser
        MYSQL_PASSWORD: password
      ports:
        - "3306:3306"
      image: mysql:latest
    figgypudding:
      environment:
        RAILS_ENV: development
        DATABASE_URL: mysql2://figgyuser:password@172.17.42.1:3306/figgydata
      links:
        - mysql
      ports:
        - "3000:3000"
      build: .
      command: bash -xc 'bundle exec rake db:migrate && bundle exec rails server'
    EOF

    # Rails defaults to sqlite, convert it to use mysql
    sed -i -e 's/sqlite3/mysql2/' Gemfile

    # Update the Gemfile.lock using the rails container we referenced earlier
    docker run --rm -v $(pwd):/usr/src/app -w /usr/src/app rails:latest bundle update

    # Use the fig command from my fig-docker container to fire up the Fig formation
    docker run -v $(pwd):/app -v $DOCKER_CERT_PATH:/certs -e DOCKER_CERT_PATH=/certs -e DOCKER_HOST=$DOCKER_HOST -e DOCKER_TLS_VERIFY=$DOCKER_TLS_VERIFY -ti --rm ianblenke/fig-docker fig up

After running that, there should now be a web server running on the boot2docker VM, which should generally be [http://192.168.59.103:3000/](http://192.168.59.103:3000/) as that seems to be the common boot2docker default IP.

This is fig, distilled to its essence.

Beyond this point, a developer can "fig build ; fig up" and see the latest result of their work. This is something ideally added as a git post-commit hook or a iteration harness like [Guard](https://github.com/guard/guard).

While it may not appear _pretty_ at first glance, realize that only `cat`, and `sed` were used on the host here (and very well could also themselves have also been avoided). No additional software was installed on the host, yet a rails app was created and deployed in docker containers, talking to a mysql server.

And therein lies the elegance of dockerizing application deployment: simple, clean, repeatable units of software. Orchestrated.

Have fun!

