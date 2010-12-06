noinst_LTLIBRARIES = libsynapsecore.la

VAPIDIR = $(top_srcdir)/vapi

libsynapsecore_la_VALAFLAGS = \
	--pkg gtk+-2.0 \
	--pkg gee-1.0 \
	--pkg json-glib-1.0 \
	--pkg dbus-glib-1 \
	--pkg gio-unix-2.0 \
	--vapidir $(VAPIDIR) \
	$(VAPIDIR)/config.vapi \
	$(VAPIDIR)/cancellable-fix.vapi \
	$(NULL)

libsynapsecore_la_CFLAGS = $(SYNAPSE_MODULES_CFLAGS) -include config.h
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
	relevancy-backend-zg.vala \
	result-set.vala \
	utils.vala \
	$(NULL)
libsynapsecore_la_SOURCES = \
	synapse-core.vala.stamp \
	$(libsynapsecore_la_VALASOURCES:.vala=.c) \
	$(NULL)

if HAVE_ZEITGEIST
libsynapsecore_la_VALAFLAGS += --pkg zeitgeist-1.0 -D HAVE_ZEITGEIST
libsynapsecore_la_CFLAGS += $(ZEITGEIST_CFLAGS)
libsynapsecore_la_LIBADD += $(ZEITGEIST_LIBS)
endif

synapse-core.vapi synapse-core.vala.stamp: $(libsynapsecore_la_VALASOURCES)
	$(AM_V_GEN)$(VALAC) $(libsynapsecore_la_VALAFLAGS) -C -H synapse-core.h --library synapse-core $^
	touch $@

BUILT_SOURCES = synapse-core.vala.stamp

EXTRA_DIST = \
	$(libsynapsecore_la_VALASOURCES) \
	synapse-core.vapi \
	synapse-core.vala.stamp \
	synapse-core.h

