AC_INIT([synapse], [0.2.99.1])
AC_DEFINE(RELEASE_NAME, "Cholecystokinin", "Codename of this release")

AC_PREREQ([2.65])

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_SRCDIR([.])
AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE([1.11 tar-ustar dist-xz no-dist-gzip -Wno-portability subdir-objects])

AM_MAINTAINER_MODE([enable])

dnl ==============================================
dnl Translation support
dnl ==============================================

GETTEXT_PACKAGE=AC_PACKAGE_NAME
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, ["$GETTEXT_PACKAGE"], [Define the gettext package to be used])
IT_PROG_INTLTOOL([0.35.0])

PKG_PROG_PKG_CONFIG([0.21])

AC_PROG_INSTALL
AC_PROG_CC
AM_PROG_CC_C_O

LT_PREREQ([2.2.6])
LT_INIT

LT_LIB_M

dnl ==============================================
dnl Check for Vala
dnl ==============================================
AM_PROG_VALAC([0.24.0])
if test "x$VALAC" = "x"; then
	AC_MSG_ERROR([You need Vala compiler])
fi

AM_SILENT_RULES([yes])

dnl ==============================================
dnl Check that we meet the dependencies
dnl ==============================================
MIN_GLIB_VERSION=2.40.0
MIN_GTK_VERSION=3.0.0
MIN_ZEITGEIST_VERSION=0.9.14
MIN_GEE_VERSION=0.5.2
MIN_JSON_VERSION=0.10.0

PKG_CHECK_MODULES(SYNAPSE_MODULES, \
  glib-2.0 >= $MIN_GLIB_VERSION \
  gdk-x11-3.0 >= $MIN_GTK_VERSION \
  gtk+-3.0 >= $MIN_GTK_VERSION \
  gio-2.0 >= $MIN_GLIB_VERSION \
  gio-unix-2.0 \
  gobject-2.0 \
  gthread-2.0 \
  gee-0.8 >= $MIN_GEE_VERSION \
  json-glib-1.0 >= $MIN_JSON_VERSION \
  keybinder-3.0 \
  libnotify
  )
SYNAPSE_MODULES_VALAFLAGS=" --pkg gdk-x11-3.0 \
  --pkg gtk+-3.0 \
  --pkg gio-2.0 \
  --pkg gio-unix-2.0 \
  --pkg gee-0.8 \
  --pkg json-glib-1.0 \
  --pkg keybinder-3.0 \
  --pkg libnotify"
AC_SUBST(SYNAPSE_MODULES_VALAFLAGS)

SYNAPSE_COMMON_VALAFLAGS=" --target-glib=2.40 --thread -g"
AC_SUBST(SYNAPSE_COMMON_VALAFLAGS)

AC_ARG_ENABLE(librest,
              AS_HELP_STRING([--enable-librest[=@<:@no/auto/yes@:>@]],[Build support for plugins using librest ]),
              [enable_librest=$enableval],
              [enable_librest="auto"])

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
	PKG_CHECK_EXISTS([zeitgeist-2.0 >= $MIN_ZEITGEIST_VERSION],,
	                 AC_MSG_ERROR([zeitgeist-2.0 is not installed]))
	PKG_CHECK_MODULES(ZEITGEIST, zeitgeist-2.0 >= $MIN_ZEITGEIST_VERSION)
	ZEITGEIST_VALAFLAGS=" --pkg zeitgeist-2.0 -D HAVE_ZEITGEIST"
	AC_SUBST(ZEITGEIST_VALAFLAGS)
	AC_DEFINE(HAVE_ZEITGEIST, 1, [Have Zeitgeist])
fi
AM_CONDITIONAL(HAVE_ZEITGEIST, test "x$enable_zeitgeist" = "xyes")

if test "x$enable_indicator" = "xauto" ; then
	PKG_CHECK_EXISTS([appindicator3-0.1],
	                 enable_indicator="yes",
	                 enable_indicator="no")
fi

if test "x$enable_indicator" = "xyes" ; then
	PKG_CHECK_EXISTS([appindicator3-0.1],,
	                 AC_MSG_ERROR([appindicator3-0.1 is not installed]))
	PKG_CHECK_MODULES(APP_INDICATOR, appindicator3-0.1)
	APP_INDICATOR_VALAFLAGS=" --pkg appindicator3-0.1 -D HAVE_INDICATOR"
	AC_SUBST(APP_INDICATOR_VALAFLAGS)
	AC_DEFINE(HAVE_INDICATOR, 1, [Have AppIndicator])
fi
AM_CONDITIONAL(HAVE_INDICATOR, test "x$enable_indicator" = "xyes")

if test "x$enable_librest" = "xauto" ; then
	PKG_CHECK_EXISTS([rest-0.7],
	                 enable_librest="yes",
	                 enable_librest="no")
fi

if test "x$enable_librest" = "xyes" ; then
	PKG_CHECK_EXISTS([rest-0.7],,
	                 AC_MSG_ERROR([rest-0.7 is not installed]))
	PKG_CHECK_MODULES(REST, rest-0.7)
	REST_VALAFLAGS=" --pkg rest-0.7 -D HAVE_LIBREST"
	AC_SUBST(REST_VALAFLAGS)
	AC_DEFINE(HAVE_LIBREST, 1, [Have librest])
fi
AM_CONDITIONAL(HAVE_LIBREST, test "x$enable_librest" = "xyes")

AC_CONFIG_FILES([
Makefile
data/Makefile
src/Makefile
src/core/Makefile
src/plugins/Makefile
src/ui/Makefile
po/Makefile.in
vapi/Makefile
])

AC_OUTPUT

cat <<EOF

${PACKAGE}-${VERSION}

  Build Environment
    Install Prefix:     ${prefix}
    Zeitgeist support:  ${enable_zeitgeist}

  Optional dependencies
    Rest:               ${enable_librest}
    AppIndicator:       ${enable_indicator}

EOF

if test "x$enable_zeitgeist" != "xyes" ; then
	AC_MSG_WARN([Zeitgeist is disabled, building without relevancy backend!])
fi

