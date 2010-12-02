SUBDIRS = tile-view

bin_PROGRAMS = synapse

VAPIDIR = $(top_srcdir)/vapi

synapse_VALAFLAGS = \
	--pkg dbus-glib-1 \
	--pkg gtk+-2.0 \
	--pkg gio-unix-2.0 \
	--pkg zeitgeist-1.0 \
	--pkg gee-1.0 \
	--pkg json-glib-1.0 \
	--pkg unique-1.0 \
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
	-I$(top_srcdir)/src/tile-view \
	$(NULL)

synapse_LDADD = \
	$(SYNAPSE_MODULES_LIBS) \
	tile-view/libtileview.la \
	$(NULL)

synapse_SOURCES = \
	configuration.vala \
	common-actions.vala \
	data-sink.vala \
	plugin.vala \
	match.vala \
	query.vala \
	result-set.vala \
	dbus-service.vala \
	desktop-file-service.vala \
	command-plugin.vala \
	desktop-file-plugin.vala \
	dictionary.vala \
	devhelp-search.vala \
	directory-plugin.vala \
	hybrid-search-plugin.vala \
	locate-plugin.vala \
	gnome-session-plugin.vala \
	upower-plugin.vala \
	zeitgeist-plugin.vala \
	rhythmbox-plugin.vala \
	banshee-plugin.vala \
	test-slow-plugin.vala \
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

