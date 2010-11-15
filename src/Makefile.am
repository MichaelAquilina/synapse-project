synapsedir = $(bindir)

synapse_PROGRAMS = synapse

synapse_VALAFLAGS = \
	--pkg dbus-glib-1 \
	--pkg gtk+-2.0 \
	--pkg gio-unix-2.0 \
	--pkg zeitgeist-1.0 \
	--pkg gee-1.0 \
	--pkg gtkhotkey-1.0 \
	--vapidir $(top_srcdir)/vapi \
	keysyms.vapi \
	cancellable-fix.vapi \
	$(NULL)

synapse_CFLAGS = $(SYNAPSE_MODULES_CFLAGS)
synapse_LDADD = $(SYNAPSE_MODULES_LIBS)
synapse_SOURCES = \
	common-actions.vala \
	data-sink.vala \
	match.vala \
	query.vala \
	dbus-service.vala \
	desktop-file-service.vala \
	command-plugin.vala \
	desktop-file-plugin.vala \
	dictionary.vala \
	devhelp-search.vala \
	directory-plugin.vala \
	hybrid-search-plugin.vala \
	gnome-session-plugin.vala \
	upower-plugin.vala \
	zeitgeist-plugin.vala \
	rhythmbox-plugin.vala \
	test-slow-plugin.vala \
	ui-cairo-gtk.vala \
	ui-cairo-gtk-mini.vala \
	ui-interface.vala \
	ui-widgets.vala \
	ui-utils.vala \
	ui-cairo-gtk-launcher.vala \
	ui-settings.vala \
	abstract-tile-object.vala \
	tile.vala \
	tile-view.vala \
	wrap-label.vala \
	$(NULL)

