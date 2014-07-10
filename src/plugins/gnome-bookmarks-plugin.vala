/*
 * Copyright (C) 2014 Rico Tzschichholz <ricotz@ubuntu.com>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Synapse
{
  public class GnomeBookmarksPlugin : Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
    }

    public void deactivate ()
    {
    }

    private class BookmarkMatch : UriMatch
    {
      public BookmarkMatch (string name, string url, string? description = null)
      {
        Object (title: name, description: description ?? url, uri: url,
                mime_type: "",
                has_thumbnail: false, icon_name: "bookmark-new");
      }

      private string? title_folded = null;
      private string? uri_folded = null;

      public unowned string get_title_folded ()
      {
        if (title_folded == null) title_folded = title.casefold ();
        return title_folded;
      }

      public unowned string get_uri_folded ()
      {
        if (uri_folded == null) uri_folded = uri.casefold ();
        return uri_folded;
      }
    }

    static void register_plugin ()
    {
      PluginRegistry.get_default ().register_plugin (
        typeof (GnomeBookmarksPlugin),
        _("GNOME Bookmarks Plugin"),
        _("Browse and open GNOME bookmarks."),
        "bookmark-new",
        register_plugin
      );
    }

    static construct
    {
      register_plugin ();
    }

    private Utils.AsyncOnce<Gee.List<BookmarkMatch>> bookmarks_once;

    construct
    {
      bookmarks_once = new Utils.AsyncOnce<Gee.List<BookmarkMatch>> ();
    }

    private void full_search (Query q, ResultSet results, MatcherFlags flags = 0)
    {
      var matchers = Query.get_matchers_for_query (q.query_string_folded, flags);

      foreach (var bmk in bookmarks_once.get_data ())
      {
        unowned string name = bmk.get_title_folded ();
        unowned string url = bmk.get_uri_folded ();

        foreach (var matcher in matchers)
        {
          if (matcher.key.match (name))
          {
            results.add (bmk, matcher.value);
            break;
          }
          if (url != null && matcher.key.match (url))
          {
            results.add (bmk, matcher.value);
            break;
          }
        }
      }
    }

    public bool handles_query (Query query)
    {
      return (QueryFlags.PLACES in query.query_type);
    }

    public async ResultSet? search (Query q) throws SearchError
    {
      var result = new ResultSet ();

      if (!bookmarks_once.is_initialized ())
      {
        yield parse_bookmarks ();
      }

      if (q.query_string.char_count () == 1)
      {
        var flags = MatcherFlags.NO_SUBSTRING | MatcherFlags.NO_PARTIAL |
                    MatcherFlags.NO_FUZZY;
        full_search (q, result, flags);
      }
      else
      {
        full_search (q, result);
      }

      q.check_cancellable ();

      return result;
    }

    private async void parse_bookmarks ()
    {
      var is_locked = yield bookmarks_once.enter ();
      if (!is_locked) return;

      var bookmarks = new Gee.ArrayList<BookmarkMatch> ();
      var filename = get_bookmarks_filename ();

      try
      {
        string contents;
        string[] lines;
        if (FileUtils.get_contents (filename, out contents))
        {
          lines = contents.split ("\n");
          foreach (unowned string line in lines)
          {
            var parts = line.split (" ", 2);
            if (parts[0] == null)
              continue;
            if (parts[1] == null)
              parts[1] = GLib.Path.get_basename (parts[0]);

            bookmarks.add (new BookmarkMatch (parts[1], parts[0],
                           (parts[0].has_prefix ("file://") ? Filename.from_uri (parts[0]) : null)));
          }
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }

      bookmarks_once.leave (bookmarks);
    }

    static string get_bookmarks_filename ()
    {
      var filename = Path.build_filename (Environment.get_user_config_dir (), "gtk-3.0", "bookmarks");
      var exists = FileUtils.test (filename, FileTest.EXISTS);

      if (exists)
        return filename;

      var legacy_filename = Path.build_filename (Environment.get_home_dir (), ".gtk-bookmarks");
      var legacy_exists = FileUtils.test (legacy_filename, FileTest.EXISTS);

      if (legacy_exists)
        return legacy_filename;

      return filename;
    }
  }
}
