/*
 * Copyright (C) 2011 Michael Aquilina <michaelaquilina@gmail.com>
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
 * Authored by Michael Aquilina <michaelaquilina@gmail.com>
 *
 */

namespace Synapse
{
  public class ZimPlugin : Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    private List<ZimPageMatch> notes;
    private FileMonitor tomboy_monitor;

    public void activate ()
    {
      File note_storage = File.new_for_path (
        "%s/Notebooks".printf (Environment.get_home_dir ())
      );
      try {
        notes = list_notebooks (note_storage);
      } catch (Error err) {
        warning ("%s", err.message);
      }

      tomboy_monitor = note_storage.monitor (FileMonitorFlags.SEND_MOVED, null);
      tomboy_monitor.set_rate_limit (500);
      tomboy_monitor.changed.connect ( (src, dest, event) => {
        string src_path = src.get_path ();
        if (src_path.has_suffix (".note")) {
          message ("Reloading notes due to change in %s (%s)", src_path, event.to_string ());
          try {
            notes = list_notebooks (note_storage);
          } catch (Error err) {
            warning ("Unable to list zim notes: %s", err.message);
          }
        }
      });
    }

    public void deactivate ()
    {
      tomboy_monitor.cancel();
    }

    static void register_plugin ()
    {
      PluginRegistry.get_default ().register_plugin (
        typeof (ZimPlugin),
        _("Zim"),
        _("Search for Zim pages."),
        "zim",
        register_plugin,
        Environment.find_program_in_path ("zim") != null,
        _("Zim is not installed")
      );
    }

    static construct
    {
      register_plugin ();
    }

    private List<ZimPageMatch> list_notebooks(File directory) throws Error {
      List<ZimPageMatch> result = new List<ZimPageMatch> ();

      FileEnumerator enumerator = directory.enumerate_children (
        FileAttribute.STANDARD_NAME + "," +
        FileAttribute.STANDARD_TYPE,
        FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
        null
      );

      FileInfo? info = null;
      while ((info = enumerator.next_file (null)) != null) {
        if (info.get_file_type () == FileType.DIRECTORY) {
          string file_name = info.get_name ();
          File notebook = directory.get_child (file_name);
          result.concat(list_all_zim_pages(notebook, notebook));
        }
      }
      return result;
    }

    private List<ZimPageMatch> list_all_zim_pages (File notebook, File directory, string prefix="") throws Error {
      List<ZimPageMatch> result = new List<ZimPageMatch> ();

      FileEnumerator enumerator = directory.enumerate_children (
        FileAttribute.STANDARD_NAME + "," +
        FileAttribute.STANDARD_TYPE,
        FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
        null
      );

      FileInfo? info = null;
      while ((info = enumerator.next_file (null)) != null) {
        string file_name = info.get_name ();

        if (info.get_file_type () == FileType.DIRECTORY) {
          File sub_page_directory = directory.get_child (file_name);
          result.concat (
            list_all_zim_pages (notebook, sub_page_directory, "%s:".printf(file_name))
          );

        } else if (info.get_file_type() == FileType.REGULAR && file_name.has_suffix (".txt")) {
          try {
            string page = file_name.replace("_", " ").replace(".txt", "");

            var match = new ZimPageMatch(
              notebook.get_basename (),
              "%s%s".printf(prefix, page)
            );
            result.append (match);
          } catch (Error err) {
            warning ("%s", err.message);
          }
        }
      }
      return result;
    }

    public bool handles_query (Query query)
    {
      return (QueryFlags.ACTIONS in query.query_type);
    }

    public async ResultSet? search (Query query) throws SearchError
    {
      var matchers = Query.get_matchers_for_query (
        query.query_string, 0,
        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS
      );

      var results = new ResultSet ();
      foreach (unowned ZimPageMatch note in notes)
      {
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (note.title)) {
            results.add (note, MatchScore.GOOD);
            break;
          }
        }
      }

      // make sure this method is called before returning any results
      query.check_cancellable ();
      if (results.size > 0) {
        return results;
      } else {
        return null;
      }
    }

    private class ZimPageMatch : ActionMatch
    {
      private string notebook;
      private string page;

      public ZimPageMatch (string notebook, string page)
      {
        Object (title: _("%s - %s").printf (notebook, page),
                description: _("Open Zim Page"),
                has_thumbnail: false,
                icon_name: "zim");
        this.notebook = notebook;
        this.page = page;
      }

      public override void do_action ()
      {
        try
        {
          Process.spawn_async (null,
            {"zim", this.notebook, this.page},
            null,
            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
            null, null
          );
        } catch (Error err) {
          warning ("%s", err.message);
        }
      }
    }
  }
}
