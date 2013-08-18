# vim: set ft=automake ts=8 sts=8 sw=8 :
include $(top_srcdir)/Makefile.common

bin_PROGRAMS = synapse

VAPIDIR = $(top_srcdir)/vapi

synapse_VALAFLAGS = \
	--pkg dbus-glib-1 \
	--pkg gtk+-3.0 \
	--pkg gdk-x11-3.0 \
	--pkg gio-2.0 \
	--pkg gio-unix-2.0 \
	--pkg unique-3.0 \
	--pkg gee-1.0 \
	--pkg json-glib-1.0 \
	--pkg keybinder-3.0 \
	--pkg libnotify \
	--vapidir $(top_builddir)/src/core \
	--pkg synapse-core \
	--vapidir $(top_builddir)/src/plugins \
	--pkg plugins \
	--vapidir $(top_builddir)/src/tile-view \
	--pkg tile-view \
	--vapidir $(VAPIDIR) \
	$(VAPIDIR)/config.vapi \
	$(NULL)

synapse_CFLAGS = \
	$(SYNAPSE_MODULES_CFLAGS) \
	-include config.h -w \
	-I$(top_builddir)/src/core \
	-I$(top_builddir)/src/plugins \
	-I$(top_builddir)/src/tile-view \
	$(NULL)

synapse_LDADD = \
	$(SYNAPSE_MODULES_LIBS) \
	$(top_builddir)/src/core/libsynapsecore.la \
	$(top_builddir)/src/plugins/libplugins.la \
	$(top_builddir)/src/tile-view/libtileview.la \
	-lm
	$(NULL)

if HAVE_INDICATOR
synapse_VALAFLAGS += --pkg appindicator3-0.1 -D HAVE_INDICATOR
synapse_CFLAGS += $(APP_INDICATOR_CFLAGS)
synapse_LDADD += $(APP_INDICATOR_LIBS)
endif

if HAVE_LIBREST
synapse_VALAFLAGS += -D HAVE_LIBREST
synapse_CFLAGS += $(REST_CFLAGS)
synapse_LDADD += $(REST_LIBS)
endif

if HAVE_ZEITGEIST
synapse_VALAFLAGS += --pkg zeitgeist-1.0 -D HAVE_ZEITGEIST
synapse_CFLAGS += $(ZEITGEIST_CFLAGS)
synapse_LDADD += $(ZEITGEIST_LIBS)
endif

synapse_VALASOURCES = \
	synapse-main.vala \
	keybindings.vala \
	category.vala \
	interfaces.vala \
	controller.vala \
	model.vala \
	view-base.vala \
	view-default.vala \
	view-essential.vala \
	view-doish.vala \
	view-side-doish.vala \
	view-virgilio.vala \
	widgets.vala \
	widgets-matchlistview.vala \
	icon-cache-service.vala \
	utils.vala \
	settings.vala \
	inspector.vala \
	$(NULL)

GENERATED_C_FILES = $(synapse_VALASOURCES:.vala=.c)
synapse_SOURCES = $(synapse_VALASOURCES:.vala=.c)

# we can't let make handle this, otherwise tarballs won't support configure
# flags (ie --disable-indicator won't rebuild the Vala sources)

#synapse_vala.stamp: $(addprefix $(srcdir)/,$(synapse_VALASOURCES)) Makefile
synapse_vala.stamp: $(synapse_VALASOURCES) Makefile
	$(AM_V_VALA)$(VALAC) $(synapse_VALAFLAGS) $(VALAFLAGS) -C $(filter %.vala %.c,$^)
	$(AM_V_at)touch $@

BUILT_SOURCES = synapse_vala.stamp

DISTCLEANFILES = $(GENERATED_C_FILES) synapse_vala.stamp
EXTRA_DIST = $(synapse_VALASOURCES)

# need to make sure the vala sources are rebuilt
dist-hook:
	rm -f $(addprefix $(distdir)/,$(GENERATED_C_FILES))
