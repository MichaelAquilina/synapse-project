Notes about this Fork
---------------------

Unofficial fork of the [Synapse project](https://launchpad.net/synapse-project).

I am big fan of synapse and a lot of my productivity stems from its use. Unfurtunately the official project seems
to have slowed down to a crawl and changes made upstream have become very slow to merge. For this reason I decided
to fork the project to host on github and make changes quickly myself.

I [release deb files](https://github.com/MichaelAquilina/synapse-project/releases/) for every significant change I make.

In the meanwhile I have added numerous plugins that I myself use on a daily occassion:

* [password store](https://www.passwordstore.org/) plugin (see an example of this in action [here](https://i.imgur.com/pMjck1o.gif))
* [Zim](http://www.zim-wiki.org/) plugin
* [Tomboy Notes](https://wiki.gnome.org/Apps/Tomboy) plugin
* [Gnote](https://wiki.gnome.org/Apps/Gnote) plugin
* Improvements to file change detection in [Zeal](https://zealdocs.org/) plugin
* fixes for Ubuntu 16.10

I am in no way an expert in Vala (or GTK for that matter) so most of the changes I make tend to be hackish in nature.
This will hopefully improve as I grow accustomed to the codebase and learn more about Valas libraries and build tools.

Feel free to contribute and add any of your own plugins if you wish.

Installing Synpase
------------------

See the [Releases](https://github.com/MichaelAquilina/synapse-project/releases) page for rpm and deb packages.

Alternatively, if you are using OpenSUSE you can use the following build service repo:

http://download.opensuse.org/repositories/home:/MichaelAquilina/

About Synapse
-------------

This version of Synapse officially supports only Vala 0.24 and later.

Building
--------

* Run `./autogen.sh`
* Run `make`
* Run `make install`

By default synapse is installed to `/usr` but you may specify a different location during `make install` using the `prefix` option.

For example:

`make install prefix=$HOME/builds/synapse`

Creating a DEB
--------------

You need `debuild` to create a `*.deb` file.

```
sudo apt-get install devscripts
```

First, update the version of synapse so that you do not get any conflicting versions:

* Update `<version>` in `AC_INIT([synapse], [<version>])` found in `configure.ac`
* Add an entry in `debian/changelog` for the new version along with a summary of changes

All you need to do now is run the following command in the root project directory:

```
debuild -b -us -uc
```

Two `*.deb` files will be created in the parent directory of the project.

One will be a production debian file and the other will be a debug version.
The version number should be correctly included as part of the name of the files.
