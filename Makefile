SRC_FILES = $(wildcard *.vala)
VALA_FLAGS = --pkg zeitgeist-1.0 --pkg gtk+-2.0 --pkg gio-unix-2.0 --pkg gee-1.0
OUTPUT = sezen2

$(OUTPUT): $(SRC_FILES)
	valac $(VALA_FLAGS) -o sezen2 $(SRC_FILES)

all: $(OUTPUT)

cdebug:
	valac $(VALA_FLAGS) -C $(SRC_FILES)

clean:
	rm -f $(OUTPUT)
