
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

    private string? title_folded = null;
    public unowned string get_title_folded ()
    {
      if (title_folded == null) title_folded = title.casefold ();
      return title_folded;
    }

    public void execute ()
    {
      var de = new DesktopAppInfo.from_filename (full_path);
      try
      {
        de.launch (null, null); // de.launch (null, new Gdk.AppLaunchContext ());
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
    }

    public string full_path { get; construct set; }
    public string exec { get; set; }

    public bool is_valid { get; private set; default = true; }

    private static string GROUP = "Desktop Entry";

    public DesktopFileInfo.for_keyfile (string path, KeyFile keyfile)
    {
      Object (full_path: path);

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
      /* create a couple of regexes and try to match the titles
       * match with these regular expressions (with descending score):
       * 1) ^query
       * 2) \bquery
       * 4) split query and search \bq.+\bu.+\be.+\br.+\by
       * 3) split query to length parts and search \bq.*u.*e.*r.*.*y
       * 5) try to match with exec
       */
      unowned string query = q.query_string_folded;
      long query_length = q.query_string.length;

      //Regex? re1 = new Regex ("^" + query, RegexCompileFlags.OPTIMIZE);
      Regex? re2;
      Regex? re3 = null;
      Regex? re4 = null;
      try
      {
        re2 = new Regex ("\\b" + Regex.escape_string (query),
                         RegexCompileFlags.OPTIMIZE);
      }
      catch (RegexError err)
      {
        re2 = null;
      }

      if (query_length <= 5)
      {
        string pattern = "\\b";
        for (long offset = 0; offset < query_length; offset++)
        {
          bool is_last = offset == query_length - 1;
          unichar u = query.offset (offset).get_char_validated ();
          if (u != -1 && u != -2) // is valid unichar
          {
            pattern += Regex.escape_string (u.to_string ());
          }
          if (!is_last) pattern += ".+\\b";
        }
        try
        {
          re3 = new Regex (pattern, RegexCompileFlags.OPTIMIZE);
        }
        catch (RegexError err)
        {
          re3 = null;
        }
      }

      if (true)
      {
        string pattern = "\\b";
        for (long offset = 0; offset < query_length; offset++)
        {
          bool is_last = offset == query_length - 1;
          unichar u = query.offset (offset).get_char_validated ();
          if (u != -1 && u != -2) // valid unichar
          {
            pattern += Regex.escape_string (u.to_string ());
          }
          if (!is_last) pattern += ".*";
        }
        try
        {
          re4 = new Regex (pattern, RegexCompileFlags.OPTIMIZE);
        }
        catch (RegexError err)
        {
          re4 = null;
        }
      }

      foreach (var dfi in desktop_files)
      {
        unowned string folded_title = dfi.get_title_folded ();
        if (folded_title.has_prefix (query))
        {
          results.add (dfi, 90);
        }
        else if (re2.match (folded_title))
        {
          results.add (dfi, 75);
        }
        else if (re3 != null && re3.match (folded_title))
        {
          results.add (dfi, 70);
        }
        else if (re4 != null && re4.match (folded_title))
        {
          // FIXME: we need to do much smarter relevancy computation here
          // "sysmon" matching "System Monitor" is very good as opposed to
          // "seto" matching "System Monitor"
          results.add (dfi, 55);
        }
        else if (dfi.exec.has_prefix (query))
        {
          results.add (dfi, dfi.exec == query ? 80 : 60);
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
