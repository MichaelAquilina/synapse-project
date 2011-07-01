APP_ICON_NAME = synapse

desktopdir = $(datarootdir)/applications
desktop_DATA = synapse.desktop
@INTLTOOL_DESKTOP_RULE@

dist_man_MANS = synapse.1

svgicondir = $(datadir)/icons/hicolor/scalable/apps
svgicon_DATA = synapse.svg
#icons = sezen-16.png sezen-22.png sezen-24.png sezen-32.png

#ICONSIZES = 16 22 24 32
#install-icons:
#	$(foreach size,$(ICONSIZES),\
#	mkdir -p $(DESTDIR)$(datadir)/icons/hicolor/$(size)x$(size)/apps; \
#        $(INSTALL) -m644 $(srcdir)/$(APP_ICON_NAME)-$(size).png $(DESTDIR)$(datadir)/icons/hicolor/$(size)x$(size)/apps/$(APP_ICON_NAME).png || exit 1;)

gtk_update_icon_cache = gtk-update-icon-cache -f -t $(datadir)/icons/hicolor
install-data-hook: update-icon-cache
uninstall-hook: update-icon-cache
update-icon-cache:
	@-if test -z "$(DESTDIR)"; then \
		echo "Updating Gtk icon cache."; \
		$(gtk_update_icon_cache); \
	else \
		echo "*** Icon cache not updated.  After (un)install, run this:"; \
		echo "***   $(gtk_update_icon_cache)"; \
	fi

#uninstall-local:
#	$(foreach size,$(ICONSIZES),\
#	rm -f $(DESTDIR)$(datadir)/icons/hicolor/$(size)x$(size)/apps/$(APP_ICON_NAME).png;)

EXTRA_DIST =            \
        $(svgicon_DATA) \
	synapse.desktop.in \
        $(NULL)

CLEANFILES = $(desktop_DATA)

