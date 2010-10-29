SRC_FILES = \
	common-actions.vala \
	data-sink.vala \
	match.vala \
	query.vala \
	dbus-service.vala \
	desktop-file-plugin.vala \
	hybrid-search-plugin.vala \
	gnome-session-plugin.vala \
	upower-plugin.vala \
	zeitgeist-plugin.vala \
	$(NULL)

VALA_FLAGS = --pkg zeitgeist-1.0 --pkg dbus-glib-1 --pkg gtk+-2.0 --pkg gio-unix-2.0 --pkg gee-1.0 --pkg gtkhotkey-1.0 --vapidir ./
VAPIS = keysyms.vapi cancellable-fix.vapi
OUTPUT = sezen2

$(OUTPUT): $(SRC_FILES) FORCE
	valac $(VALA_FLAGS) $(VAPIS) -g -o $@ $(SRC_FILES)

.PHONY: all
all: $(OUTPUT)

cdebug: VALA_FLAGS += -C
#cdebug: SRC_FILES += ui-cairo-gtk.vala
cdebug: all

gtk: SRC_FILES += ui-basic-gtk.vala
gtk: all

cmd: SRC_FILES += ui-cmd-line.vala
cmd: all

cairo: SRC_FILES += ui-cairo-gtk.vala ui-interface.vala ui-utils.vala
cairo: all

cairodebug: VALA_FLAGS += -C
cairodebug: SRC_FILES += ui-cairo-gtk.vala ui-interface.vala ui-utils.vala
cairodebug: all

FORCE:

clean:
	rm -f $(OUTPUT)
