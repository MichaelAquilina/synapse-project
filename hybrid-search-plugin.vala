
namespace Sezen
{
  public class HybridSearchPlugin: DataPlugin
  {
    private class MatchObject: Object, Match
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public string uri { get; set; }

      public void execute ()
      {
        var f = File.new_for_uri (uri);
        var app_info = f.query_default_handler (null);
        List<File> files = new List<File> ();
        files.prepend (f);
        app_info.launch (files, new Gdk.AppLaunchContext ());
      }

      public MatchObject (string? thumbnail_path, string? icon)
      {
        Object (has_thumbnail: thumbnail_path != null,
                icon_name: icon ?? "",
                thumbnail_path: thumbnail_path ?? "");
      }
    }

    private class FileInfo
    {
      public string uri;
      public MatchObject? match_obj;

      public FileInfo (string uri)
      {
        this.uri = uri;
        this.match_obj = null;
      }
    }

    private class DirectoryInfo
    {
      public string path;
      public TimeVal last_update;
      public Gee.Map<string, FileInfo?> files;

      public DirectoryInfo (string path)
      {
        this.files = new Gee.HashMap<string, FileInfo?> ();
        this.path = path;
      }
    }

    construct
    {
      directory_hits = new Gee.HashMap<string, int> ();
      directory_contents = new Gee.HashMap<string, FileInfo?> ();
    }

    protected override void constructed ()
    {
      // FIXME: if zeitgeist-plugin available
      data_sink.plugin_search_done.connect (this.zg_plugin_search_done);
    }

    private void zg_plugin_search_done (DataPlugin plugin, ResultSet rs)
    {
      if (plugin.get_type ().name ().has_prefix ("SezenZeitgeistPlugin"))
      {
        // let's mine directories ZG is aware of
        Gee.Set<string> uris = new Gee.HashSet<string> ();
        foreach (var match in rs) uris.add (match.key.uri);

        int current_hit_level = hit_level;

        process_uris.begin (uris, (obj, res) =>
        {
          process_uris.end (res);

          current_level_uris = uris.size;
          hit_level = current_hit_level+1;
          debug ("Hit_level: %d - %d uris", hit_level, current_level_uris);

          hits_updated (rs);
        });
      }
    }

    public signal void hits_updated (ResultSet original_rs);

    Gee.Map<string, int> directory_hits;
    int hit_level = 0;
    int current_level_uris = 0;

    private async void process_uris (Gee.Collection<string> uris)
    {
      Gee.Set<string> dirs = new Gee.HashSet<string> ();

      foreach (var uri in uris)
      {
        var f = File.new_for_uri (uri);
        try
        {
          if (f.is_native ())
          {
            var fi = yield f.query_info_async (FILE_ATTRIBUTE_STANDARD_TYPE,
                                               0, 0, null);
            if (fi.get_file_type () == FileType.REGULAR)
            {
              string? parent_path = f.get_parent ().get_path ();
              if (parent_path != null) dirs.add (parent_path);
            }
          }
        }
        catch (Error err)
        {
          continue;
        }
      }

      int q_len = (int) current_query.length;
      foreach (var dir in dirs)
      {
        if (dir in directory_hits)
        {
          int hit_count = directory_hits[dir];
          directory_hits[dir] = hit_count + q_len;
        }
        else
        {
          directory_hits[dir] = q_len;
        }
      }
    }

    private string interesting_attributes =
      string.join (",", FILE_ATTRIBUTE_STANDARD_TYPE,
                        FILE_ATTRIBUTE_STANDARD_ICON,
                        FILE_ATTRIBUTE_THUMBNAIL_PATH,
                        null);

    private Gee.List<string> get_most_likely_dirs ()
    {
      int MAX_ITEMS = 2;
      var result = new Gee.ArrayList<string> ();

      if (directory_hits.size <= MAX_ITEMS)
      {
        // too few results, use all we have
        foreach (var dir in directory_hits.keys) result.add (dir);
      }
      else
      {
        var sort_array = new Gee.ArrayList<Gee.Map.Entry<unowned string, int>> ();
        int min_hit = int.MAX;
        foreach (var entry in directory_hits.entries)
        {
          if (entry.value < min_hit) min_hit = entry.value;
        }
        foreach (var entry in directory_hits.entries)
        {
          if (entry.value > min_hit) sort_array.add (entry);
        }
        sort_array.sort ((a, b) =>
        {
          unowned Gee.Map.Entry<unowned string, int> e1 =
            (Gee.Map.Entry<unowned string, int>) a;
          unowned Gee.Map.Entry<unowned string, int> e2 =
            (Gee.Map.Entry<unowned string, int>) b;
          return e2.value - e1.value;
        });

        int count = 0;
        foreach (var entry in sort_array)
        {
          result.add (entry.key);
          if (count++ >= MAX_ITEMS-1) break;
        }
      }

      return result;
    }

    Gee.Map<string, DirectoryInfo> directory_contents;

    private void process_directory_contents (DirectoryInfo di,
                                             File directory,
                                             List<GLib.FileInfo> files)
    {
      di.last_update = TimeVal ();
      foreach (var f in files)
      {
        unowned string name = f.get_name ();
        var child = directory.get_child (name);
        di.files[child.get_uri ()] = null;
      }
    }

    private async void process_directories (Gee.Collection<string> directories)
    {
      foreach (var dir_path in directories)
      {
        var directory = File.new_for_path (dir_path);
        try
        {
          DirectoryInfo di;
          if (dir_path in directory_contents)
          {
            var cur_time = TimeVal ();
            di = directory_contents[dir_path];
            if (cur_time.tv_sec - di.last_update.tv_sec <= 5 * 60)
            {
              // info fairly fresh, continue
              continue;
            }
          }
          else
          {
            di = new DirectoryInfo (dir_path);
            directory_contents[dir_path] = di;
          }

          var enumerator = yield directory.enumerate_children_async (
            FILE_ATTRIBUTE_STANDARD_NAME, 0, 0);
          var files = yield enumerator.next_files_async (1024, 0);

          process_directory_contents (di, directory, files);
        }
        catch (Error err)
        {
        }
      }
    }

    private string? current_query = null;
    public override async ResultSet? search (Query q) throws SearchError
    {
      var result = new ResultSet ();

      // what about deleting one character?
      if (current_query != null && !q.query_string.has_prefix (current_query))
      {
        hit_level = 0;
        current_level_uris = 0;
        directory_hits.clear ();
      }
      current_query = q.query_string;
      int last_level_uris = current_level_uris;
      ResultSet? original_rs = null;

      // wait for our signal or cancellable
      ulong sig_id = this.hits_updated.connect ((rs) =>
      {
        original_rs = rs;
        search.callback ();
      });
      ulong canc_sig_id = CancellableFix.connect (q.cancellable, () =>
      {
        // who knows what thread this runs in
        SignalHandler.block (this, sig_id); // is this thread-safe?
        Idle.add (search.callback); // FIXME: this could cause issues
      });
      yield;
      SignalHandler.disconnect (this, sig_id);
      q.cancellable.disconnect (canc_sig_id);

      q.check_cancellable ();

      // we weren't cancelled and we should have some directories and hits
      if (hit_level > 1)
      {
        // we want [current_level_uris / last_level_uris > 0.66]
        if (current_level_uris * 3 > 2 * last_level_uris)
        {
          var directories = get_most_likely_dirs ();
          debug ("we're in level: %d and we'd crawl these dirs >\n%s",
                 hit_level, string.joinv ("; ", directories.to_array ()));
          yield process_directories (directories);

          // directory contents are updated now, we can take a look if any
          // files match our query
        }
      }

      return result;
    }
  }
}
