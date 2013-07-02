# vim: set ft=automake ts=8 sts=8 sw=8 :
include $(top_srcdir)/Makefile.common

noinst_LTLIBRARIES = libsynapsecore.la

VAPIDIR = $(top_srcdir)/vapi

libsynapsecore_la_VALAFLAGS = \
	--pkg gtk+-3.0 \
	--pkg gee-1.0 \
	--pkg json-glib-1.0 \
	--pkg dbus-glib-1 \
	--pkg gio-unix-2.0 \
	--vapidir $(VAPIDIR) \
	$(VAPIDIR)/config.vapi \
	$(NULL)

libsynapsecore_la_CFLAGS = $(SYNAPSE_MODULES_CFLAGS) -include config.h -w -lm
libsynapsecore_la_LIBADD = $(SYNAPSE_MODULES_LIBS)
libsynapsecore_la_VALASOURCES = \
	common-actions.vala \
	config-service.vala \
	data-sink.vala \
	dbus-service.vala \
	desktop-file-service.vala \
	match.vala \
	plugin.vala \
	query.vala \
	relevancy-service.vala \
	result-set.vala \
	utils.vala \
	volume-service.vala \
	$(NULL)

if HAVE_ZEITGEIST
libsynapsecore_la_VALASOURCES += relevancy-backend-zg.vala
libsynapsecore_la_VALAFLAGS += --pkg zeitgeist-1.0 -D HAVE_ZEITGEIST
libsynapsecore_la_CFLAGS += $(ZEITGEIST_CFLAGS)
libsynapsecore_la_LIBADD += $(ZEITGEIST_LIBS)
endif

GENERATED_C_FILES = $(libsynapsecore_la_VALASOURCES:.vala=.c)
libsynapsecore_la_SOURCES = \
	$(libsynapsecore_la_VALASOURCES:.vala=.c) \
	$(NULL)

synapse-core.vapi synapse-core.vala.stamp: $(libsynapsecore_la_VALASOURCES) Makefile
	$(AM_V_VALA)$(VALAC) $(libsynapsecore_la_VALAFLAGS) -C -H synapse-core.h --library synapse-core --gir SynapseCore-1.0.gir $(filter %.vala %.c,$^)
	touch $@

BUILT_SOURCES = synapse-core.vala.stamp

EXTRA_DIST = \
	$(libsynapsecore_la_VALASOURCES) \
	$(NULL)

DISTCLEANFILES = \
	$(libsynapsecore_la_VALASOURCES:.vala=.c) \
	synapse-core.vala.stamp \
	synapse-core.vapi \
	synapse-core.h \
	SynapseCore-1.0.gir \
	$(NULL)

dist-hook:
	rm -f $(addprefix $(distdir)/,$(GENERATED_C_FILES))

