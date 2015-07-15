# vim: set ft=automake ts=8 sts=8 sw=8 :
include $(top_srcdir)/Makefile.common

noinst_LTLIBRARIES = libsynapsecore.la

VAPIDIR = $(top_srcdir)/vapi

libsynapsecore_la_VALAFLAGS = \
	$(SYNAPSE_COMMON_VALAFLAGS) \
	$(SYNAPSE_MODULES_VALAFLAGS) \
	--vapidir $(VAPIDIR) \
	$(VAPIDIR)/config.vapi \
	$(NULL)

libsynapsecore_la_CFLAGS = $(SYNAPSE_MODULES_CFLAGS) -include config.h -w
libsynapsecore_la_LIBADD = $(SYNAPSE_MODULES_LIBS) $(LIBM)
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
libsynapsecore_la_VALAFLAGS += $(ZEITGEIST_VALAFLAGS)
libsynapsecore_la_CFLAGS += $(ZEITGEIST_CFLAGS)
libsynapsecore_la_LIBADD += $(ZEITGEIST_LIBS)
endif

nodist_libsynapsecore_la_SOURCES = \
	$(libsynapsecore_la_VALASOURCES:.vala=.c) \
	$(NULL)

synapse-core.h synapse-core.vapi: synapse-core.vala.stamp

synapse-core.vala.stamp: $(libsynapsecore_la_VALASOURCES) Makefile
	$(AM_V_VALA)$(VALAC) $(libsynapsecore_la_VALAFLAGS) -C -H synapse-core.h --library synapse-core $(filter %.vala %.c,$^)
	$(AM_V_at)touch $@

BUILT_SOURCES = \
	synapse-core.vala.stamp \
	synapse-core.h \
	$(NULL)

EXTRA_DIST = \
	$(libsynapsecore_la_VALASOURCES) \
	$(NULL)

CLEANFILES = \
	$(nodist_libsynapsecore_la_SOURCES) \
	synapse-core.vala.stamp \
	synapse-core.vapi \
	synapse-core.h \
	$(NULL)

