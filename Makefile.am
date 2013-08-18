SUBDIRS = \
	src \
	vapi \
	data \
	po \
	$(NULL)

ACLOCAL_AMFLAGS = -I m4

EXTRA_DIST = \
	Makefile.common \
	COPYING.GPL2 \
	COPYING.LGPL2.1 \
	$(NULL)

# make sure we have translations in the tarball
dist-hook:
	@test -n "$(wildcard $(top_srcdir)/po/*.po)" || (echo "Translations are missing! Please merge lp:~mhr3/synapse-project/synapse-i18n" && exit 1)
