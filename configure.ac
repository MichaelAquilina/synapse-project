AC_INIT([synapse], [0.2.1])
AC_DEFINE(RELEASE_NAME, "Acetylcholine", "Codename of this release")

#AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([.])
AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE([1.11])

dnl ==============================================
dnl Translation support
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
AM_PROG_CC_C_O
AC_PROG_LIBTOOL
AC_STDC_HEADERS

dnl ==============================================
dnl Check for Vala
dnl ==============================================
AM_PROG_VALAC([0.9.7])

AM_SILENT_RULES([yes])

dnl ==============================================
dnl Check that we meet the dependencies
dnl ==============================================
MIN_GLIB_VERSION=2.22.0
MIN_GTK_VERSION=2.20.0
MIN_ZEITGEIST_VERSION=0.2.14
MIN_GEE_VERSION=0.5.2
MIN_JSON_VERSION=0.10.0
APPINDICATOR_REQUIRED=0.0.7

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
  )


AC_ARG_ENABLE(indicator,
              AS_HELP_STRING([--enable-indicator[=@<:@no/auto/yes@:>@]],[Build support for application indicators ]),
              [enable_indicator=$enableval],
              [enable_indicator="auto"])

AC_ARG_ENABLE(zeitgeist,
             AS_HELP_STRING([--enable-zeitgeist[=@<:@no/yes@:>@]],[Build with zeitgeist support]),
             [enable_zeitgeist=$enableval],
             [enable_zeitgeist="yes"])

dnl ==============================================
dnl Check that we meet the optional dependencies
dnl ==============================================

if test "x$enable_zeitgeist" = "xyes" ; then
	PKG_CHECK_EXISTS([zeitgeist-1.0 >= $MIN_ZEITGEIST_VERSION],,
	                 AC_MSG_ERROR([zeitgeist-1.0 is not installed]))
	PKG_CHECK_MODULES(ZEITGEIST, zeitgeist-1.0 >= $MIN_ZEITGEIST_VERSION)
	AC_DEFINE(HAVE_ZEITGEIST, 1, [Have Zeitgeist])
fi
AM_CONDITIONAL(HAVE_ZEITGEIST, test "x$enable_zeitgeist" = "xyes")

if test "x$enable_indicator" = "xauto" ; then
	PKG_CHECK_EXISTS([appindicator-0.1 >= $APPINDICATOR_REQUIRED],
	                 enable_indicator="yes",
	                 enable_indicator="no")
fi

if test "x$enable_indicator" = "xyes" ; then
	PKG_CHECK_EXISTS([appindicator-0.1 >= $APPINDICATOR_REQUIRED],,
	                 AC_MSG_ERROR([appindicator-0.1 is not installed]))
	PKG_CHECK_MODULES(APP_INDICATOR, appindicator-0.1 >= $APPINDICATOR_REQUIRED)
	AC_DEFINE(HAVE_INDICATOR, 1, [Have AppIndicator])
fi
AM_CONDITIONAL(HAVE_INDICATOR, test "x$enable_indicator" = "xyes")

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
src/core/Makefile
src/plugins/Makefile
src/tile-view/Makefile
po/Makefile.in
])


AC_OUTPUT

cat <<EOF

${PACKAGE}-${VERSION}

  Build Environment
    Install Prefix:     ${prefix}

  Optional dependencies
    AppIndicator:       ${enable_indicator}
    Zeitgeist:          ${enable_zeitgeist}

EOF
