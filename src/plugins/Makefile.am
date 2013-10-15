# vim: set ft=automake ts=8 sts=8 sw=8 :
include $(top_srcdir)/Makefile.common

# these shouldn't actually be noinst... we'll fix that later
noinst_LTLIBRARIES = libplugins.la

VAPIDIR = $(top_srcdir)/vapi

libplugins_la_VALAFLAGS = \
	--pkg gtk+-3.0 \
	--pkg gee-1.0 \
	--pkg json-glib-1.0 \
	--pkg dbus-glib-1 \
	--pkg gio-unix-2.0 \
	--pkg libnotify \
	--vapidir $(top_builddir)/src/core \
	--pkg synapse-core \
	--vapidir $(VAPIDIR) \
	$(VAPIDIR)/config.vapi \
	$(NULL)

libplugins_la_CFLAGS = \
	$(SYNAPSE_MODULES_CFLAGS) \
	-include config.h -w \
	-I$(top_builddir)/src/core \
	$(NULL)
libplugins_la_LIBADD = \
	$(SYNAPSE_MODULES_LIBS) \
	$(top_builddir)/src/core/libsynapsecore.la \
	$(NULL)
libplugins_la_VALASOURCES = \
	banshee-plugin.vala \
	calculator-plugin.vala \
	chat-actions-plugin.vala \
	chromium-plugin.vala \
	command-plugin.vala \
	file-op-plugin.vala \
	desktop-file-plugin.vala \
	devhelp-search.vala \
	ssh-plugin.vala \
	dictionary.vala \
	directory-plugin.vala \
	gnome-session-plugin.vala \
	gnome-screensaver-plugin.vala \
	hello-world-plugin.vala \
	hybrid-search-plugin.vala \
	launchpad-plugin.vala \
	locate-plugin.vala \
	opensearch.vala \
	pastebin-plugin.vala \
	pidgin-plugin.vala \
	rhythmbox-plugin.vala \
	selection-plugin.vala \
	test-slow-plugin.vala \
	xnoise-media-player-plugin.vala \
	system-management.vala \
	$(NULL)

if HAVE_ZEITGEIST
libplugins_la_VALASOURCES += zeitgeist-plugin.vala zeitgeist-related.vala
libplugins_la_VALAFLAGS += --pkg zeitgeist-1.0 -D HAVE_ZEITGEIST
libplugins_la_CFLAGS += $(ZEITGEIST_CFLAGS)
libplugins_la_LIBADD += $(ZEITGEIST_LIBS)
endif

if HAVE_LIBREST
libplugins_la_VALASOURCES += imgur-plugin.vala
libplugins_la_VALAFLAGS += --pkg rest-fix -D HAVE_LIBREST
libplugins_la_CFLAGS += $(REST_CFLAGS)
libplugins_la_LIBADD += $(REST_LIBS)
endif

GENERATED_C_FILES = $(libplugins_la_VALASOURCES:.vala=.c)
libplugins_la_SOURCES = \
	$(libplugins_la_VALASOURCES:.vala=.c) \
	$(NULL)

plugins.vapi plugins.vala.stamp: $(libplugins_la_VALASOURCES) Makefile
	$(AM_V_VALA)$(VALAC) $(libplugins_la_VALAFLAGS) -C -H plugins.h --library plugins $(filter %.vala %.c,$^)
	touch $@

BUILT_SOURCES = plugins.vala.stamp

EXTRA_DIST = \
	$(libplugins_la_VALASOURCES) \
	$(NULL)

DISTCLEANFILES = \
	$(libplugins_la_VALASOURCES:.vala=.c) \
	plugins.vala.stamp \
	plugins.vapi \
	plugins.h \
	$(NULL)

# need to make sure the vala sources are rebuilt
dist-hook:
	rm -f $(addprefix $(distdir)/,$(GENERATED_C_FILES))

