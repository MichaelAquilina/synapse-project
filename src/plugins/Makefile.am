# these shouldn't actually be noinst... we'll fix that later
noinst_LTLIBRARIES = libplugins.la

VAPIDIR = $(top_srcdir)/vapi

libplugins_la_VALAFLAGS = \
	--pkg gtk+-2.0 \
	--pkg gee-1.0 \
	--pkg json-glib-1.0 \
	--pkg dbus-glib-1 \
	--pkg gio-unix-2.0 \
	--pkg zeitgeist-1.0 \
	--vapidir $(srcdir)/../core \
	--pkg synapse-core \
	--vapidir $(VAPIDIR) \
	$(VAPIDIR)/config.vapi \
	$(VAPIDIR)/cancellable-fix.vapi \
	$(NULL)

libplugins_la_CFLAGS = \
	$(SYNAPSE_MODULES_CFLAGS) \
	-include config.h \
        -I$(top_srcdir)/src/core \
	$(NULL)
libplugins_la_LIBADD = $(SYNAPSE_MODULES_LIBS)
libplugins_la_VALASOURCES = \
	banshee-plugin.vala \
	command-plugin.vala \
	desktop-file-plugin.vala \
	devhelp-search.vala \
	dictionary.vala \
	directory-plugin.vala \
	gnome-session-plugin.vala \
	hybrid-search-plugin.vala \
	locate-plugin.vala \
	rhythmbox-plugin.vala \
	test-slow-plugin.vala \
	upower-plugin.vala \
	zeitgeist-plugin.vala \
	$(NULL)
libplugins_la_SOURCES = \
	plugins.vala.stamp \
	$(libplugins_la_VALASOURCES:.vala=.c) \
	$(NULL)

plugins.vapi plugins.vala.stamp: $(libplugins_la_VALASOURCES)
	$(AM_V_GEN)$(VALAC) $(libplugins_la_VALAFLAGS) -C -H plugins.h --library plugins $^
	touch $@

BUILT_SOURCES = plugins.vala.stamp

EXTRA_DIST = \
	$(libplugins_la_VALASOURCES) \
	plugins.vapi \
	plugins.vala.stamp \
	plugins.h
