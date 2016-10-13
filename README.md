This version of Synapse officially supports only Vala 0.24 and later.

Building
--------

* Run `./autogen.sh`
* Run `make`
* Run `make install`

By default synapse is installed to `/usr` but you may specify a different location during `./autogen.sh` setup using the `--prefix` option.

For example:

`./autogen.sh --prefix ~/builds/synapse`

Creating a DEB
--------------

You need `debuild` to create a `*.deb` file.

```
sudo apt-get install devscripts
```

First, update the version of synapse so that you do not get any conflicting versions:

* Update `<version>` in `AC_INIT([synapse], [<version>])` found in `configure.ac`. Run `./autogen.sh`.
* Add an entry in `debian/changelog` for the new version along with a summary of changes

All you need to do now is run the following command in the root project directory:

```
debuild -b -us -uc
```

Two `*.deb` files will be created in the parent directory of the project. 

One will be a production debian file and the other will be a debug version. 
The version number should be correctly included as part of the name of the files.
