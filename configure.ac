AC_INIT([synapse], [0.1.1])
AC_DEFINE(RELEASE_NAME, "Acetylcholine", "Codename of this release")

#AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([.])
AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE([1.11])

dnl ==============================================
dnl translation support
dnl ==============================================

GETTEXT_PACKAGE=synapse
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE,"$GETTEXT_PACKAGE", [Gettext package])
ALL_LINGUAS=""

IT_PROG_INTLTOOL([0.35])
AM_GLIB_GNU_GETTEXT

dnl -- Populate top_srcdir variable
top_srcdir=$(readlink -f $0 | sed -e s/configure$//)

dnl pkg-config
AC_PATH_PROG(PKG_CONFIG, pkg-config, no)
if test "x$PKG_CONFIG" = "xno"; then
        AC_MSG_ERROR([You need to install pkg-config])
fi

AC_PROG_INSTALL
AC_PROG_CC
AC_STDC_HEADERS

dnl ==============================================
dnl Check for vala
dnl ==============================================
AM_PROG_VALAC([0.9.7])

AM_SILENT_RULES([yes])

dnl ==============================================
dnl Check that we meet the dependencies
dnl ==============================================
MIN_GLIB_VERSION=2.22.0
MIN_GTK_VERSION=2.20.0
MIN_ZEITGEIST_VERSION=0.2.8
MIN_GEE_VERSION=0.5.2
MIN_JSON_VERSION=0.10.0

PKG_CHECK_MODULES(SYNAPSE_MODULES, \
  glib-2.0 >= $MIN_GLIB_VERSION \
  gtk+-2.0 >= $MIN_GTK_VERSION \
  gtkhotkey-1.0 \
  gobject-2.0 \
  gee-1.0 >= $MIN_GEE_VERSION \
  gio-unix-2.0 \
  dbus-glib-1 \
  json-glib-1.0 >= $MIN_JSON_VERSION \
  unique-1.0 \
  zeitgeist-1.0 >= $MIN_ZEITGEIST_VERSION \
  )

dnl Expansions
dnl AS_AC_EXPAND([PKGDATADIR], [$datadir/$PACKAGE_NAME])
dnl AS_AC_EXPAND([DATADIR], [$datadir])
dnl AS_AC_EXPAND([LIBDIR], [$libdir])
dnl AS_AC_EXPAND([LIBEXECDIR], [$libexecdir])

AC_DEFINE_UNQUOTED(PKGDATADIR, "$PKGDATADIR", [Package base directory])

AC_CONFIG_FILES([
Makefile
data/Makefile
src/Makefile
po/Makefile.in
])


AC_OUTPUT

cat <<EOF

${PACKAGE}-${VERSION}

  Build Environment
    Install Prefix:     ${prefix}

EOF
