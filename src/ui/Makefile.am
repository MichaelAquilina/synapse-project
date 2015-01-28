# vim: set ft=automake ts=8 sts=8 sw=8 :
include $(top_srcdir)/Makefile.common

bin_PROGRAMS = synapse

VAPIDIR = $(top_srcdir)/vapi

synapse_VALAFLAGS = \
	$(SYNAPSE_COMMON_VALAFLAGS) \
	$(SYNAPSE_MODULES_VALAFLAGS) \
	--basedir $(srcdir) \
	--directory $(builddir) \
	--vapidir $(top_builddir)/src/core \
	--pkg synapse-core \
	--vapidir $(top_builddir)/src/plugins \
	--pkg plugins \
	--vapidir $(VAPIDIR) \
	$(VAPIDIR)/config.vapi \
	$(NULL)

synapse_CFLAGS = \
	$(SYNAPSE_MODULES_CFLAGS) \
	-include config.h -w \
	-I$(top_builddir)/src/core \
	-I$(top_builddir)/src/plugins \
	$(NULL)

synapse_LDADD = \
	$(SYNAPSE_MODULES_LIBS) \
	$(top_builddir)/src/core/libsynapsecore.la \
	$(top_builddir)/src/plugins/libplugins.la \
	$(LIBM) \
	$(NULL)

if HAVE_INDICATOR
synapse_VALAFLAGS += $(APP_INDICATOR_VALAFLAGS)
synapse_CFLAGS += $(APP_INDICATOR_CFLAGS)
synapse_LDADD += $(APP_INDICATOR_LIBS)
endif

if HAVE_LIBREST
synapse_VALAFLAGS += $(REST_VALAFLAGS)
synapse_CFLAGS += $(REST_CFLAGS)
synapse_LDADD += $(REST_LIBS)
endif

if HAVE_ZEITGEIST
synapse_VALAFLAGS += $(ZEITGEIST_VALAFLAGS)
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
	tile-view/abstract-tile-object.vala \
	tile-view/tile.vala \
	tile-view/tile-view.vala \
	tile-view/wrap-label.vala \
	$(NULL)

GENERATED_C_FILES = $(synapse_VALASOURCES:.vala=.c)
synapse_SOURCES = $(synapse_VALASOURCES:.vala=.c)

# we can't let make handle this, otherwise tarballs won't support configure
# flags (ie --disable-indicator won't rebuild the Vala sources)

#synapse_vala.stamp: $(addprefix $(srcdir)/,$(synapse_VALASOURCES)) Makefile
synapse_vala.stamp: $(synapse_VALASOURCES) $(top_builddir)/src/core/synapse-core.vapi $(top_builddir)/src/plugins/plugins.vapi Makefile
	$(AM_V_VALA)$(VALAC) $(synapse_VALAFLAGS) $(VALAFLAGS) -C $(filter %.vala %.c,$^)
	$(AM_V_at)touch $@

BUILT_SOURCES = synapse_vala.stamp

DISTCLEANFILES = $(GENERATED_C_FILES) synapse_vala.stamp
EXTRA_DIST = $(synapse_VALASOURCES)

# need to make sure the vala sources are rebuilt
dist-hook:
	rm -f $(addprefix $(distdir)/,$(GENERATED_C_FILES))
