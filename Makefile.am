include $(top_srcdir)/Makefile.common

SUBDIRS = \
	src \
	vapi \
	data \
	po \
	$(NULL)

ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

EXTRA_DIST = \
	Makefile.common \
	COPYING.GPL2 \
	COPYING.LGPL2.1 \
	$(NULL)

distclean-local:
	if test "x$(srcdir)" = "x."; then :; else \
		rm -f ChangeLog; \
	fi

ChangeLog:
	@echo Creating $@
	@if test -d "$(srcdir)/.bzr"; then \
		(bzr log --gnu -n1) | fmt --split-only --width=80 > $@.tmp \
		&& mv -f $@.tmp $@ \
		|| ($(RM) $@.tmp; \
			echo Failed to generate ChangeLog, your ChangeLog may be outdated >&2; \
			(test -f $@ || echo bzr is required to generate this file >> $@)); \
	else \
		test -f $@ || \
		(echo A bzr checkout and bzr is required to generate ChangeLog >&2 && \
		echo A bzr checkout and bzr is required to generate this file >> $@); \
	fi

.PHONY: ChangeLog
