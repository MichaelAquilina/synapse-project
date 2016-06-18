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
  public class TomboyNotesPlugin : Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    private List<TomboyNoteMatch> notes;
    private FileMonitor tomboy_monitor;

    public void activate ()
    {
      File note_storage = File.new_for_path (
        "%s/.local/share/tomboy".printf (Environment.get_home_dir ())
      );
      try {
        notes = list_tomboy_notes (note_storage);
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
            notes = list_tomboy_notes (note_storage);
          } catch (Error err) {
            warning ("Unable to list tomboy notes: %s", err.message);
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
        typeof (TomboyNotesPlugin),
        _("Tomboy Notes"),
        _("Search for tomboy notes."),
        "tomboy",
        register_plugin,
        Environment.find_program_in_path ("tomboy") != null,
        _("Tomboy Notes is not installed")
      );
    }

    static construct
    {
      register_plugin ();
    }

    public string? get_note_title (File note_file) throws Error {
      FileIOStream ios = note_file.open_readwrite ();
      FileInputStream @is = ios.input_stream as FileInputStream;
      DataInputStream dis = new DataInputStream (@is);

      string line;
      while ((line = dis.read_line ()) != null) {
        if (Regex.match_simple ("<title>.*</title>", line)) {
          line = line.replace ("<title>", "");
          line = line.replace ("</title>", "");
          return line.strip ();
        }
      }
      dis.close();
      is.close();
      ios.close();

      return null;
    }

    private List<TomboyNoteMatch> list_tomboy_notes (File directory) throws Error {
      List<TomboyNoteMatch> result = new List<TomboyNoteMatch> ();

      FileEnumerator enumerator = directory.enumerate_children (
        FileAttribute.STANDARD_NAME + "," +
        FileAttribute.STANDARD_TYPE,
        FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
        null
      );

      FileInfo? info = null;
      while ((info = enumerator.next_file (null)) != null) {
        string file_name = info.get_name ();
        File note_file = directory.get_child (file_name);

        if (info.get_file_type () == FileType.REGULAR && file_name.has_suffix (".note")) {
          try {
            var match = new TomboyNoteMatch(
              get_note_title (note_file),
              note_file.get_path ()
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
      foreach (unowned TomboyNoteMatch note in notes)
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

    private class TomboyNoteMatch : ActionMatch
    {
      private string url;

      public TomboyNoteMatch (string note_title, string url)
      {
        Object (title: note_title,
                description: _("Open Tomboy Note"),
                has_thumbnail: false,
                icon_name: "tomboy");
        this.url = url;
      }

      public override void do_action ()
      {
        try
        {
          AppInfo ai = AppInfo.create_from_commandline (
            "tomboy --open-note %s".printf (url), "tomboy", 0
          );
          ai.launch (null, null);
        } catch (Error err) {
          warning ("%s", err.message);
        }
      }
    }
  }
}
