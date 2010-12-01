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

/* 
 * This plugin keeps a cache of file names for directories that are commonly
 * used. 
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

    private class FileInfo
    {
      private static string interesting_attributes;
      static construct
      {
        interesting_attributes =
          string.join (",", FILE_ATTRIBUTE_STANDARD_TYPE,
                            FILE_ATTRIBUTE_STANDARD_IS_HIDDEN,
                            FILE_ATTRIBUTE_STANDARD_IS_BACKUP,
                            FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME,
                            FILE_ATTRIBUTE_STANDARD_ICON,
                            FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE,
                            FILE_ATTRIBUTE_THUMBNAIL_PATH,
                            null);
      }
      
      public string uri;
      public string parse_name;
      public QueryFlags file_type;
      public MatchObject? match_obj;
      private bool initialized;

      public FileInfo (string uri)
      {
        this.uri = uri;
        this.match_obj = null;
        this.initialized = false;
        this.file_type = QueryFlags.UNCATEGORIZED;

        var f = File.new_for_uri (uri);
        this.parse_name = f.get_parse_name ();
      }
      
      public bool is_initialized ()
      {
        return this.initialized;
      }
      
      public async void initialize ()
      {
        initialized = true;
        var f = File.new_for_uri (uri);
        try
        {
          var fi = yield f.query_info_async (interesting_attributes,
                                             0, 0, null);
          if (fi.get_file_type () == FileType.REGULAR &&
              !fi.get_is_hidden () &&
              !fi.get_is_backup ())
          {
            match_obj = new MatchObject (
              fi.get_attribute_byte_string (FILE_ATTRIBUTE_THUMBNAIL_PATH),
              fi.get_icon ().to_string ());
            match_obj.uri = uri;
            match_obj.title = fi.get_display_name ();
            match_obj.description = f.get_parse_name ();
            
            // let's determine the file type
            unowned string mime_type = 
              fi.get_attribute_string (FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE);
            if (g_content_type_is_unknown (mime_type))
            {
              file_type = QueryFlags.UNCATEGORIZED;
            }
            else if (g_content_type_is_a (mime_type, "audio/*"))
            {
              file_type = QueryFlags.AUDIO;
            }
            else if (g_content_type_is_a (mime_type, "video/*"))
            {
              file_type = QueryFlags.VIDEO;
            }
            else if (g_content_type_is_a (mime_type, "image/*"))
            {
              file_type = QueryFlags.IMAGES;
            }
            else if (g_content_type_is_a (mime_type, "text/*"))
            {
              file_type = QueryFlags.DOCUMENTS;
            }
            // FIXME: this isn't right
            else if (g_content_type_is_a (mime_type, "application/*"))
            {
              file_type = QueryFlags.DOCUMENTS;
            }
            
            match_obj.file_type = file_type;
            match_obj.mime_type = mime_type;
          }
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
      
      public async bool exists ()
      {
        bool result = true;
        var f = File.new_for_uri (uri);
        try
        {
          // will throw error if the file doesn't exist
          yield f.query_info_async (FILE_ATTRIBUTE_STANDARD_TYPE,
                                    0, 0, null);
        }
        catch (Error err)
        {
          result = false;
        }
        
        return result;
      }
    }

    private class DirectoryInfo
    {
      public string path;
      public TimeVal last_update;
      public Gee.Map<unowned string, FileInfo?> files;

      public DirectoryInfo (string path)
      {
        this.files = new Gee.HashMap<unowned string, FileInfo?> ();
        this.path = path;
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (LocatePlugin),
        "Locate",
        "Runs locate command to find files on the filesystem.",
        "search",
        register_plugin
      );
    }

    static construct
    {
      register_plugin ();
    }

    Gee.Map<string, DirectoryInfo> directory_contents;

    construct
    {
      directory_contents = new Gee.HashMap<string, FileInfo?> ();
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
