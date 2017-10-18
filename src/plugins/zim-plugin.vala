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
    private List<FileMonitor> monitors;
    private File note_storage;

    public void activate ()
    {
      note_storage = File.new_for_path (
        "%s/Notebooks".printf (Environment.get_home_dir ())
      );

      update_notes ();
    }

    public void deactivate ()
    {
      foreach (unowned FileMonitor monitor in monitors) {
        monitor.cancel ();
      }
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

    private void update_notes () {
      foreach (unowned FileMonitor monitor in monitors) {
        monitor.cancel ();
      }
      monitors = null;

      try {
        monitors = activate_monitors (note_storage);
      } catch (Error err) {
        warning ("Unable to monitor note storage: %s", err.message);
      }
      try {
        notes = list_notebooks (note_storage);
      } catch (Error err) {
        warning ("Unable to list notebooks: %s", err.message);
      }
    }

    private List<FileMonitor> activate_monitors (File directory) throws Error {
      List<FileMonitor> result = new List<FileMonitor> ();

      FileEnumerator enumerator = directory.enumerate_children (
        FileAttribute.STANDARD_NAME + "," +
        FileAttribute.STANDARD_TYPE + "," +
        FileAttribute.STANDARD_IS_HIDDEN,
        FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
        null
      );

      FileMonitor monitor = directory.monitor_directory (FileMonitorFlags.NONE, null);
      monitor.set_rate_limit (500);
      monitor.changed.connect ((src, dest, event) => {
        message ("Detected a change (%s) in zim Notebooks directory. Reloading", event.to_string ());
        update_notes ();
      });
      result.append (monitor);

      FileInfo? info = null;
      while ((info = enumerator.next_file (null)) != null) {
        if (info.get_is_hidden ()) continue;

        File target_file = directory.get_child (info.get_name ());
        if (info.get_file_type () == FileType.DIRECTORY) {
          result.concat (activate_monitors (target_file));
        }
      }

      return result;
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
          string page = file_name;
          if (prefix != "") {
            page = "%s:%s".printf(prefix, page);
          }
          result.concat (
            list_all_zim_pages (notebook, sub_page_directory, page)
          );

        } else if (info.get_file_type() == FileType.REGULAR && file_name.has_suffix (".txt")) {
          string page = file_name.replace("_", " ").replace(".txt", "");
          if (prefix != "") {
            page = "%s:%s".printf(prefix.replace("_", " "), page);
          }

          var match = new ZimPageMatch(notebook.get_basename (), page);
          result.append (match);
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
