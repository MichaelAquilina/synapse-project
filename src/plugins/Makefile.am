# vim: set ft=automake ts=8 sts=8 sw=8 :
include $(top_srcdir)/Makefile.common

noinst_LTLIBRARIES = libplugins.la

VAPIDIR = $(top_srcdir)/vapi

libplugins_la_VALAFLAGS = \
	$(SYNAPSE_COMMON_VALAFLAGS) \
	$(SYNAPSE_MODULES_VALAFLAGS) \
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
	gnome-bookmarks-plugin.vala \
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
	zeal-plugin.vala \
	$(NULL)

if HAVE_ZEITGEIST
libplugins_la_VALASOURCES += zeitgeist-plugin.vala zeitgeist-related.vala
libplugins_la_VALAFLAGS += $(ZEITGEIST_VALAFLAGS)
libplugins_la_CFLAGS += $(ZEITGEIST_CFLAGS)
libplugins_la_LIBADD += $(ZEITGEIST_LIBS)
endif

if HAVE_LIBREST
libplugins_la_VALASOURCES += imgur-plugin.vala
libplugins_la_VALAFLAGS += $(REST_VALAFLAGS)
libplugins_la_CFLAGS += $(REST_CFLAGS)
libplugins_la_LIBADD += $(REST_LIBS)
endif

nodist_libplugins_la_SOURCES = \
	$(libplugins_la_VALASOURCES:.vala=.c) \
	$(NULL)

plugins.h plugins.vapi: plugins.vala.stamp

plugins.vala.stamp: $(libplugins_la_VALASOURCES) $(top_builddir)/src/core/synapse-core.vapi Makefile
	$(AM_V_VALA)$(VALAC) $(libplugins_la_VALAFLAGS) -C -H plugins.h --library plugins $(filter %.vala %.c,$^)
	$(AM_V_at)touch $@

BUILT_SOURCES = \
	plugins.vala.stamp \
	plugins.h \
	$(NULL)

EXTRA_DIST = \
	$(libplugins_la_VALASOURCES) \
	$(NULL)

CLEANFILES = \
	$(nodist_libplugins_la_SOURCES) \
	plugins.vala.stamp \
	plugins.vapi \
	plugins.h \
	$(NULL)

