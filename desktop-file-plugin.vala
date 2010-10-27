/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Sezen
{
  errordomain DesktopFileError
  {
    UNINTERESTING_ENTRY
  }

  public class DesktopFileInfo: Object, Match
  {
    // for Match interface
    public string title { get; construct set; }
    public string description { get; set; default = ""; }
    public string icon_name { get; construct set; default = ""; }
    public bool has_thumbnail { get; construct set; default = false; }
    public string thumbnail_path { get; construct set; }
    public string uri { get; set; }
    public MatchType match_type { get; construct set; }

    private string? title_folded = null;
    public unowned string get_title_folded ()
    {
      if (title_folded == null) title_folded = title.casefold ();
      return title_folded;
    }

    public string exec { get; set; }

    public bool is_valid { get; private set; default = true; }

    private static string GROUP = "Desktop Entry";

    public DesktopFileInfo.for_keyfile (string path, KeyFile keyfile)
    {
      Object (uri: path, match_type: MatchType.DESKTOP_ENTRY);

      init_from_keyfile (keyfile);
    }

    private void init_from_keyfile (KeyFile keyfile)
    {
      try
      {
        if (keyfile.get_string (GROUP, "Type") != "Application")
        {
          throw new DesktopFileError.UNINTERESTING_ENTRY ("Not Application-type desktop entry");
        }

        title = keyfile.get_locale_string (GROUP, "Name");
        exec = keyfile.get_string (GROUP, "Exec");

        // check for hidden desktop files
        if (keyfile.has_key (GROUP, "Hidden") &&
          keyfile.get_boolean (GROUP, "Hidden"))
        {
          is_valid = false;
          return;
        }
        if (keyfile.has_key (GROUP, "NoDisplay") &&
          keyfile.get_boolean (GROUP, "NoDisplay"))
        {
          is_valid = false;
          return;
        }
        if (keyfile.has_key (GROUP, "Comment"))
        {
          description = keyfile.get_locale_string (GROUP, "Comment");
        }
        if (keyfile.has_key (GROUP, "Icon"))
        {
          icon_name = keyfile.get_locale_string (GROUP, "Icon");
          if (!Path.is_absolute (icon_name) &&
              (icon_name.has_suffix (".png") ||
              icon_name.has_suffix (".svg") ||
              icon_name.has_suffix (".xpm")))
          {
            icon_name = icon_name.ndup (icon_name.size () - 4);
          }
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
        is_valid = false;
      }
    }
  }

  public class DesktopFilePlugin: DataPlugin
  {
    private Gee.List<DesktopFileInfo> desktop_files;

    construct
    {
      desktop_files = new Gee.ArrayList<DesktopFileInfo> ();

      load_all_desktop_files ();
    }

    public signal void load_complete ();
    private bool loading_in_progress = false;

    private async void load_all_desktop_files ()
    {
      string[] data_dirs = Environment.get_system_data_dirs ();
      data_dirs += Environment.get_user_data_dir ();

      loading_in_progress = true;

      foreach (unowned string data_dir in data_dirs)
      {
        string dir_path = Path.build_filename (data_dir, "applications", null);
        try
        {
          var directory = File.new_for_path (dir_path);
          if (!directory.query_exists ()) continue;
          var enumerator = yield directory.enumerate_children_async (
            FILE_ATTRIBUTE_STANDARD_NAME, 0, 0);
          var files = yield enumerator.next_files_async (1024, 0);
          foreach (var f in files)
          {
            unowned string name = f.get_name ();
            if (name.has_suffix (".desktop"))
            {
              yield load_desktop_file (directory.get_child (name));
            }
          }
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }

      loading_in_progress = false;
      load_complete ();
    }

    private async void load_desktop_file (File file)
    {
      try
      {
        size_t len;
        string contents;
        bool success = yield file.load_contents_async (null, 
                                                       out contents, out len);
        if (success)
        {
          var keyfile = new KeyFile ();
          keyfile.load_from_data (contents, len, 0);
          var dfi = new DesktopFileInfo.for_keyfile (file.get_path(), keyfile);
          if (dfi.is_valid) desktop_files.add (dfi);
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
    }

    private void simple_search (Query q, ResultSet results)
    {
      // search method used for 1 letter searches
      unowned string query = q.query_string_folded;

      foreach (var dfi in desktop_files)
      {
        if (dfi.get_title_folded ().has_prefix (query))
        {
          results.add (dfi, 90);
        }
        else if (dfi.exec.has_prefix (q.query_string))
        {
          results.add (dfi, 60);
        }
      }
    }

    private void full_search (Query q, ResultSet results)
    {
      // try to match against global matchers and if those fail, try also exec
      var matchers = Query.get_matchers_for_query (q.query_string_folded);

      foreach (var dfi in desktop_files)
      {
        unowned string folded_title = dfi.get_title_folded ();
        bool matched = false;
        // FIXME: we need to do much smarter relevancy computation in fuzzy re
        // "sysmon" matching "System Monitor" is very good as opposed to
        // "seto" matching "System Monitor"
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (folded_title))
          {
            results.add (dfi, matcher.value);
            matched = true;
            break;
          }
        }
        if (!matched && dfi.exec.has_prefix (q.query_string))
        {
          results.add (dfi, dfi.exec == q.query_string ? 85 : 65);
        }
      }
    }

    public override async ResultSet? search (Query q) throws SearchError
    {
      if (!(QueryFlags.APPLICATIONS in q.query_type)) return null;

      if (loading_in_progress)
      {
        // wait
        ulong signal_id = this.load_complete.connect (() =>
        {
          search.callback ();
        });
        yield;
        SignalHandler.disconnect (this, signal_id);
      }
      else
      {
        // we'll do this so other plugins can send their DBus requests etc.
        // and they don't have to wait for our blocking (though fast) search
        // to finish
        Idle.add (search.callback);
        yield;
      }

      q.check_cancellable ();

      // FIXME: spawn new thread and do the search there?
      var result = new ResultSet ();

      if (q.query_string.length == 1)
      {
        simple_search (q, result);
      }
      else
      {
        full_search (q, result);
      }

      q.check_cancellable ();

      return result;
    }
  }
}
