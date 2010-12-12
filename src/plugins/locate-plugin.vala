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

namespace Synapse
{
  public class LocatePlugin: DataPlugin
  {
    private class MatchObject: Object, Match, UriMatch
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      // for FileMatch
      public string uri { get; set; }
      public QueryFlags file_type { get; set; }
      public string mime_type { get; set; }

      public MatchObject (string? thumbnail_path, string? icon)
      {
        Object (match_type: MatchType.GENERIC_URI,
                has_thumbnail: thumbnail_path != null,
                icon_name: icon ?? "",
                thumbnail_path: thumbnail_path ?? "");
      }
    }

    private class LocateItem: Object, Match
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }
      
      public LocateItem ()
      {
        Object (match_type: MatchType.SEARCH,
                has_thumbnail: false,
                icon_name: "search",
                description: _ ("Locate files with this name on the filesystem"));
      }
    }

    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (LocatePlugin),
        _ ("Locate"),
        _ ("Runs locate command to find files on the filesystem."),
        "search",
        register_plugin,
        Environment.find_program_in_path ("locate") != null,
        _ ("Unable to find \"locate\" binary")
      );
    }

    static construct
    {
      register_plugin ();
    }

    construct
    {
    }

    public override async ResultSet? search (Query q) throws SearchError
    {
      var our_results = QueryFlags.AUDIO | QueryFlags.DOCUMENTS
        | QueryFlags.IMAGES | QueryFlags.UNCATEGORIZED | QueryFlags.VIDEO;

      var common_flags = q.query_type & our_results;
      // strip query
      q.query_string = q.query_string.strip ();
      // ignore short searches
      if (common_flags == 0 || q.query_string.length <= 1) return null;

      Timeout.add (90, search.callback);
      yield;

      q.check_cancellable ();

      // FIXME: split pattern into words and search using --regexp?
      string[] argv = {"locate", "-i", "-l", "%u".printf (q.max_results),
                       q.query_string};

      Gee.Set<string> uris = new Gee.HashSet<string> ();

      try
      {
        Pid pid;
        int read_fd;

        // FIXME: fork on every letter... yey!
        Process.spawn_async_with_pipes (null, argv, null,
                                        SpawnFlags.SEARCH_PATH,
                                        null, out pid, null, out read_fd);

        UnixInputStream read_stream = new UnixInputStream (read_fd, true);
        DataInputStream locate_output = new DataInputStream (read_stream);
        string? line = null;

        Regex filter_re = new Regex ("/\\."); // hidden file/directory
        do
        {
          line = yield locate_output.read_line_async (Priority.DEFAULT_IDLE, q.cancellable);
          if (line != null)
          {
            if (!line.has_prefix ("/home") || filter_re.match (line)) continue;
            uris.add (line);
          }
        } while (line != null);
      }
      catch (Error err)
      {
        if (!q.is_cancelled ()) warning ("%s", err.message);
      }

      q.check_cancellable ();

      foreach (string s in uris) debug ("%s", s);

      var result = new ResultSet ();
      return result;
    }
  }
}
