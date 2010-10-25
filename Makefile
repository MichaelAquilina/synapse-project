SRC_FILES = \
	data-sink.vala \
	desktop-file-plugin.vala \
	hybrid-search-plugin.vala \
	query.vala \
	zeitgeist-plugin.vala \
	$(NULL)

VALA_FLAGS = --pkg zeitgeist-1.0 --pkg gtk+-2.0 --pkg gio-unix-2.0 --pkg gee-1.0 --pkg gtkhotkey-1.0 --vapidir ./
VAPIS = keysyms.vapi cancellable-fix.vapi
OUTPUT = sezen2

$(OUTPUT): $(SRC_FILES)
	valac $(VALA_FLAGS) $(VAPIS) -g -o $@ $(SRC_FILES)

.PHONY: all
all: $(OUTPUT)

cdebug: VALA_FLAGS += -C
cdebug: SRC_FILES += ui-cairo-gtk.vala
cdebug: all

gtk: SRC_FILES += ui-basic-gtk.vala
gtk: all

cmd: SRC_FILES += ui-cmd-line.vala
cmd: all

cairo: SRC_FILES += ui-cairo-gtk.vala
cairo: all

clean:
	rm -f $(OUTPUT)
