+++
date = "2014-11-04T22:41:53-05:00"
draft = false
title = "Installing Boot2Docker"
description = "A quick guide to installing Boot2Docker"
#comment = "Both command-line and point-and-click installation guide for boot2docker"
#linkedin_share = "https://www.linkedin.com/nhome/updates?topic=5938521225469911040"
#date_formatted = "Nov 4th, 2014"
#comments = true
categories = ["boot2docker"]
+++

Starting with a new team of developers, it helps to document the bootstrapping steps to a development environment.

Rather than try and use a convergence tool like Chef, Puppet, Ansible, or SALT, this time the environment will embrace Docker.

We could use a tool like Vagrant, but we need to support both Windows and Mac development workstations, and Vagrant under Windows can be vexing.

For this, we will begin anew using [Boot2Docker](http://boot2docker.io)

Before we begin, be sure to install [VirtualBox](https://www.virtualbox.org/) from Oracle's [VirtualBox.org website](https://www.virtualbox.org/)

The easiest way to install VirtualBox is to use [HomeBrew Cask](http://caskroom.io/) under [HomeBrew](http://brew.sh)

    brew install caskroom/cask/brew-cask
    brew cask install virtualbox

The easiest way to install boot2docker is to use [HomeBrew](http://brew.sh)

    brew install boot2docker

Afterward, be sure to upgrade the homebrew bottle to the latest version of boot2docker:

    boot2docker upgrade

Alternatively, a sample commandline install of boot2docker might look like this:

    wget https://github.com/boot2docker/osx-installer/releases/download/v1.3.1/Boot2Docker-1.3.1.pkg
    sudo installer -pkg ~/Downloads/Boot2Docker-1.3.1.pkg -target /

I'll leave the commandline install of VirtualBox up to your imagination. With [HomeBrew Cask](http://caskroom.io), there's really not much of a point.

If you're still not comfortable, below is a pictoral screenshot guide to installing boot2docker the point-and-click way.

Step 0
------

Download [boot2docker for OS/X](https://github.com/boot2docker/osx-installer/releases) or [boot2docker for Windows](https://github.com/boot2docker/windows-installer/releases)

Step 1
------

Run the downloaded Boot2Docker.pkg or docker-install.exe to kick off the installer.

![Boot2docker.pkg in Downloads folder](/images/screenshots/boot2docker/step1-downloads.png)

Step 2
------

Click the Continue button to allow the installer to run a program to detect if boot2docker can be installed.</p>

![Allow installer to run a program to detect if boot2docker can be installed](/images/screenshots/boot2docker/step2-run-a-program.png)

Step 3
------

Click the Continue button to proceed beyond the initial installation instructions dialog.

![Instructions to install boot2docker](/images/screenshots/boot2docker/step3-install-splash.png)

Step 4
------

The installer will now ask for an admin username/password to obtain admin rights to install boot2docker.

![Installer asks for admin rights to install boot2docker](/images/screenshots/boot2docker/step4-enter-password.png)

Step 5
------

Before installing, the installer will advise how much space the install will take. Click the Install button to start the actual install.

![Advice on how much space boot2docker will take when installed](/images/screenshots/boot2docker/step5-standard-install.png)

Step 6
------

When the installation is successfully, click the Close button to exit the installer.

![Install completed successfully](/images/screenshots/boot2docker/step6-install-completed-successfully.png)

Step 7
------

You now have a shiny icon for boot2docker in /Applications you can click on to start a boot2docker terminal window session.

![Boot2docker app is in Applications](/images/screenshots/boot2docker/step7-installed-boot2docker-app.png)

Congrats. You now have boot2docker installed.
