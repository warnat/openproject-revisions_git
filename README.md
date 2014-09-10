# OpenProject Revisions/Git Plugin

This plugin aims to provide extensive features for managing Git repositories within [OpenProject](http://www.openproject.org).
Forked from [jbox-web's version](https://jbox-web.github.io/redmine_git_hosting/) of the long-lived, often-forked redmine-git_hosting plugin (formerly redmine-gitosis).

As OpenProject has diverted quite a bit in terms of project management (e.g., redmine allows multiple repositories per project), some features have been removed in the fork.

**Disclaimer**: This fork is still in progress. While some things work, it is by no means stable.

## Overview

* Depends on **Gitolite (v2/v3)**
* Acts as a **wrapper to the gitolite-admin** to feed gitolite with SSH keys, repository information
* Employs **libgit2/rugged** through [gitolite-rugged](https://github.com/oliverguenther/gitolite-rugged).

## Features

**SSH Public-Key Management (Gitolite)**

✓ Multiple keys per user

**Gitolite Repository Management**

✓ Managing repositories with Gitolite upon creation, update/deletion. (Async w/ delayed_jobs)

✓ Members/Roles access written to Gitolite.

✓ SSH-based access (through Gitolite).

**Planned / Forked, but non-functional / non-tested features**
(*Ordered by my own subjective importance.*)

* Git Smart-HTTP (Access through https in OpenProject)
* Post-Receive Hooks
* Repository Mirrors
* Deployment Keys
* Initialize Repositories with Readme

**Stripped/Changed features from jbox-web's version**

* Sidekiq (OpenProject uses delayed_jobs instead)
* SELinux (unfamiliar, can't provide a good fork)
* GitHub features (Issues), should be separate plugin
* Git access cache ( belongs in the core )
* Repository Recycle bin after deletion (Just use your filesystem backups)
* Notifications / Mailing lists

## Installation

##### 0. (preliminary) [Setup Gitolite v2/v3](http://gitolite.com/gitolite/install.html)

I'm assuming you have some basic knowledge of Gitolite and:

* are in possession of a SSH key pair set up for use with gitolite.
* have successfully cloned the gitolite-admin.git repository from the user running OpenProject.

##### 1. Gemfile.plugins

Add a Gemfile.plugins to your OpenProject root with the following contents:

	gem "openproject-revisions_git", :git => "https://github.com/oliverguenther/openproject-revisions_git.git", :branch => "dev"

##### 2. Sudo rights

Ensure the user running OpenProject can sudo to the gitolite user.

Assuming that user is called *openproject* and the gitolite user is *git*, open visudo and add:

	openproject        ALL=(git)      NOPASSWD:ALL
	
##### 3. Gitolite access

Make sure you can ssh into gitolite from the openproject user. If you run the following command, the output below (or similar for gitolite2) should appear. **If it does not, this is a gitolite configuration error.**

	openproject$ ssh -i <gitolite-admin SSH key> git@localhost info
	hello openproject, this is git@dev running gitolite3 v3.x-x on git x.x.x
	    R W  gitolite-admin
	    R W  testing
	    
##### 4. Configuration in OpenProject

Run OpenProject, go to **Admin > Plugins > OpenProject Revisions/Git** (click on configure)

Alter you configuration for Gitolite (Gitolite path, gitolite-admin.git path, etc.) accordingly and click save.

##### 5. Config Test

Check that the output on the tab 'Config Test' looks good.
Note that many of the settings are not yet functional, and some values on config test are thus irrelevant (Hooks, for example).

## Basic Usage

#### Managing SSH keys

1. Log in, go to My Account (top right).
2. Select 'Public Keys' in the menu on the left.
3. Add/Manage your public key using the form.

#### Managing repositories

1. Create project.
2. Go to repositories settings and select Git + click create. This should automatically create the corresponding entry in the gitolite configuration.
3. Use members to add a member to the repository. If that user has a public key on record, the corresponding access rights will be written to Gitolite.


## Copyrights & License
OpenProject Revisions/Git is completely free and open source and released under the [MIT License](https://github.com/oliverguenther/openproject_revisions_git/blob/devel/LICENSE).

Copyright (c) 2014 Oliver Günther (mail@oliverguenther.de)

This plugin bases on the [Redmine Git Hosting plugin by Nicolas Rodriguez](https://github.com/jbox-web/redmine_git_hosting)

Copyright (c) 2013-2014 Nicolas Rodriguez (nrodriguez@jbox-web.com), JBox Web (http://www.jbox-web.com)

Copyright (c) 2011-2013 John Kubiatowicz (kubitron@cs.berkeley.edu)

Copyright (c) 2010-2011 Eric Bishop (ericpaulbishop@gmail.com)

Copyright (c) 2009-2010 Jan Schulz-Hofen, Rocket Rentals GmbH (http://www.rocket-rentals.de)
