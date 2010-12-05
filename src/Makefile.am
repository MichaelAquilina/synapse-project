SUBDIRS = core plugins tile-view

bin_PROGRAMS = synapse

VAPIDIR = $(top_srcdir)/vapi

synapse_VALAFLAGS = \
	--pkg dbus-glib-1 \
	--pkg gtk+-2.0 \
	--pkg gio-2.0 \
	--pkg gio-unix-2.0 \
	--pkg zeitgeist-1.0 \
	--pkg gee-1.0 \
	--pkg json-glib-1.0 \
	--pkg unique-1.0 \
	--vapidir $(srcdir)/core \
	--pkg synapse-core \
	--vapidir $(srcdir)/plugins \
	--pkg plugins \
	--vapidir $(srcdir)/tile-view \
	--pkg tile-view \
	--vapidir $(VAPIDIR) \
	--pkg gtkhotkey-1.0 \
	$(VAPIDIR)/keysyms.vapi \
	$(VAPIDIR)/cancellable-fix.vapi \
	$(VAPIDIR)/config.vapi \
	$(NULL)

synapse_CFLAGS = \
	$(SYNAPSE_MODULES_CFLAGS) \
	-include config.h \
	-I$(top_srcdir)/src/core \
	-I$(top_srcdir)/src/plugins \
	-I$(top_srcdir)/src/tile-view \
	$(NULL)

synapse_LDADD = \
	$(SYNAPSE_MODULES_LIBS) \
	core/libsynapsecore.la \
	plugins/libplugins.la \
	tile-view/libtileview.la \
	$(NULL)

if HAVE_INDICATOR
synapse_VALAFLAGS += --pkg appindicator-0.1 -D HAVE_INDICATOR
synapse_CFLAGS += $(APP_INDICATOR_CFLAGS)
synapse_LDADD += $(APP_INDICATOR_LIBS)
endif

if HAVE_ZEITGEIST
synapse_VALAFLAGS += --pkg zeitgeist-1.0 -D HAVE_ZEITGEIST
synapse_CFLAGS += $(ZEITGEIST_CFLAGS)
synapse_LDADD += $(ZEITGEIST_LIBS)
endif

synapse_SOURCES = \
	synapse-main.vala \
	ui-cairo-gtk-base.vala \
	ui-cairo-gtk.vala \
	ui-cairo-gtk-mini.vala \
	ui-cairo-gtk-two-lines.vala \
	ui-cairo-gtk-virgilio.vala \
	ui-interface.vala \
	ui-widgets.vala \
	ui-utils.vala \
	ui-settings.vala \
	ui-inspector.vala \
	$(NULL)

