---
layout: post
title: "Docker rspec TDD"
date: 2014-11-10 14:38:37 -0500
summary: Dockerfile TDD using rspec and boot2docker, with a working spec_helper for TLS support.
comment: A guide to test-driven design of a Dockerfile using rspec and boot2docker
linkedin_share: https://www.linkedin.com/nhome/updates?topic=5938528528290045952
date_formatted: Nov 10, 2014
comments: true
categories: docker rspec tdd
---
A Dockerfile both describes a Docker image as well as layers for the working directory, environment variables, ports, entrypoint commands, and other important interfaces.

Test-Driven Design should drive a developer toward implementation details, not the other way around.

A devops without tests is a sad devops indeed.

Working toward a docker based development environment, my first thoughts were toward [Serverspec](http://serverspec.org/) by [Gosuke Miayshita](https://github.com/mizzy), as it is entirely framework agnostic. Gosuke gave an excellent presentation at ChefConf this year re-inforcing that Serverspec is _not_ a chef centric tool, and works quite well in conjunction with other configuration management tools.

Researching Serverspec and docker a bit more, [Taichi Nakashima](https://github.com/tcnksm) based his [TDD of Dockerfile by RSpec on OS/X](https://github.com/tcnksm-sample/docker-rspec) using ssh.

With Docker 1.3 and later, there is a "docker exec" interactive docker API for allowing live sessions on processes spawned in the same process namespace as a running container, effectively allowing external access into a running docker container using only the docker API.

[PIETER JOOST VAN DE SANDE](http://blog.wercker.com/2013/12/23/Test-driven-development-for-docker.html) posted about using the docker-api to accomplish the goal of testing a Dockerfile. His work is based on the [docker-api](https://rubygems.org/gems/docker-api) gem (github [swipely/docker-api](https://github.com/swipely/docker-api)).

Looking into the docker-api source, there is no support yet for docker 1.3's exec API interface to run Serverspec tests against the contents of a running docker container.

Attempting even the most basic docker API calls with docker-api, [issue 202](https://github.com/swipely/docker-api/issues/202) made it apparent that TLS support for boot2docker would need to be addressed first.

Here is my functional `spec_helper.rb` with the fixes necessary to use docker-api without modifications:

{% gist 5335483e4021954d815f %}

Following this, I can drive the generation of a Dockerfile with a spec:

{% gist 261e6fe930c922202151 %}

This drives me iteratively to write a Dockerfile that looks like:

{% gist ef7150420cbd328d5e41 %}

Next step: extend docker-api to support exec for serverspec based testing of actual docker image contents.

Sláinte!

