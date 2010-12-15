# vim: set ft=automake ts=8 sts=8 sw=8 :
include $(top_srcdir)/Makefile.common

noinst_LTLIBRARIES = libtileview.la

VAPIDIR = $(top_srcdir)/vapi

libtileview_la_VALAFLAGS = \
	--pkg gtk+-2.0 \
	--vapidir $(VAPIDIR) \
	$(VAPIDIR)/keysyms.vapi \
	$(VAPIDIR)/config.vapi \
	$(NULL)

libtileview_la_CFLAGS = $(SYNAPSE_MODULES_CFLAGS) -include config.h
libtileview_la_LIBADD = $(SYNAPSE_MODULES_LIBS)
libtileview_la_VALASOURCES = \
	abstract-tile-object.vala \
	tile.vala \
	tile-view.vala \
	wrap-label.vala \
	$(NULL)
libtileview_la_SOURCES = \
	tile-view.vala.stamp \
	$(libtileview_la_VALASOURCES:.vala=.c) \
	$(NULL)

tile-view.vapi tile-view.vala.stamp: $(libtileview_la_VALASOURCES)
	$(AM_V_VALA)$(VALAC) $(libtileview_la_VALAFLAGS) -C -H tile-view.h --library tile-view $^
	touch $@

BUILT_SOURCES = tile-view.vala.stamp

EXTRA_DIST = \
	$(libtileview_la_VALASOURCES) \
	tile-view.vapi \
	tile-view.vala.stamp \
	tile-view.h

