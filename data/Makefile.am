# vim: set ft=automake ts=8 sts=8 sw=8 :
include $(top_srcdir)/Makefile.common

desktopdir = $(datarootdir)/applications
nodist_desktop_DATA = synapse.desktop

@INTLTOOL_DESKTOP_RULE@

dist_man_MANS = synapse.1

svgicondir = $(datadir)/icons/hicolor/scalable/apps
dist_svgicon_DATA = synapse.svg

EXTRA_DIST = \
	synapse.desktop.in \
	$(NULL)

CLEANFILES = \
	$(nodist_desktop_DATA) \
	$(NULL)

