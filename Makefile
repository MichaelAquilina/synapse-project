SRC_FILES = $(wildcard *.vala)
VALA_FLAGS = --pkg zeitgeist-1.0 --pkg gtk+-2.0 --pkg gio-unix-2.0 --pkg gee-1.0 --pkg gtkhotkey-1.0 --vapidir ./
VAPIS = keysyms.vapi cancellable-fix.vapi
OUTPUT = sezen2

$(OUTPUT): $(SRC_FILES)
	valac $(VALA_FLAGS) $(VAPIS) -D CMD_LINE_UI -g -o sezen2 $(SRC_FILES)

all: $(OUTPUT)

cdebug:
	valac $(VALA_FLAGS) $(VAPIS) -C $(SRC_FILES)

gtk:
	valac $(VALA_FLAGS) $(VAPIS) -g -o sezen2 $(SRC_FILES)

clean:
	rm -f $(OUTPUT)
