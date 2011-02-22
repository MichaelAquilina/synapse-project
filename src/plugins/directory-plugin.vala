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
  public class DirectoryPlugin: Object, Activatable, ItemProvider
  {
    public unowned DataSink data_sink { get; construct; }
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }

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

      public MatchObject (string uri)
      {
        Object (match_type: MatchType.GENERIC_URI,
                has_thumbnail: false,
                uri: uri,
                file_type: QueryFlags.UNCATEGORIZED,
                mime_type: "inode/directory");
      }
    }
    
    private class DirectoryInfo
    {
      public MatchObject match_obj;
      public string name;
      public string name_folded;

      public DirectoryInfo (string uri)
      {
        this.match_obj = new MatchObject (uri);
        var f = File.new_for_uri (uri);
        this.match_obj.description = f.get_path ();
      }

      private bool initialized = false;
      
      private const string ATTRIBUTE_CUSTOM_ICON = "metadata::custom-icon";

      public async void initialize ()
      {
        //debug ("getting info for %s", match_obj.uri);
        var f = File.new_for_uri (match_obj.uri);
        try
        {
          var fi = yield f.query_info_async (FILE_ATTRIBUTE_STANDARD_ICON + "," +
                                             FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME + "," +
                                             ATTRIBUTE_CUSTOM_ICON,
                                             0, Priority.DEFAULT, null);
          this.name = fi.get_display_name ();
          this.name_folded = this.name.casefold ();
          this.match_obj.title = this.name;
          this.match_obj.icon_name = fi.get_icon ().to_string ();
          if (fi.has_attribute (ATTRIBUTE_CUSTOM_ICON))
          {
            var icon_f = File.new_for_uri (fi.get_attribute_string (ATTRIBUTE_CUSTOM_ICON));
            this.match_obj.icon_name = icon_f.get_path ();
          }
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
        
        initialized = true;
      }
    }
    
    private class Config: ConfigObject
    {
      public bool home_dir_children_only { get; set; default = true; }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (DirectoryPlugin),
        "Directory Search",
        _ ("Open commonly used directories."),
        "folder",
        register_plugin
      );
    }

    static construct
    {
      register_plugin ();
    }
    
    private Gee.Map<unowned string, DirectoryInfo> directory_info_map;
    private Config config;

    construct
    {
      directory_info_map = new Gee.HashMap<unowned string, DirectoryInfo> ();
      var cs = ConfigService.get_default ();
      config = (Config) cs.get_config ("plugins", "directory-plugin", typeof (Config));
    }
    
    private bool connected_to_zg = false;

    protected override void constructed ()
    {
      // FIXME: if zeitgeist-plugin available
      unowned ItemProvider? zg_plugin;
      zg_plugin = data_sink.get_plugin ("SynapseZeitgeistPlugin") as ItemProvider;
      if (zg_plugin == null) return;

      zg_plugin.search_done.connect (this.zg_plugin_search_done);
      connected_to_zg = true;
    }
    
    private bool xdg_indexed = false;

    private async void index_xdg_directories ()
    {
      if (xdg_indexed) return;
      
      for (UserDirectory dir = UserDirectory.DESKTOP;
           dir <= UserDirectory.VIDEOS; //dir < UserDirectory.N_DIRECTORIES;
           dir = dir + 1)
      {
        var path = Environment.get_user_special_dir (dir);
        if (path == null) continue;
        var f = File.new_for_path (path);
        var uri = f.get_uri ();
        if (uri in directory_info_map) continue;

        var info = new DirectoryInfo (uri);
        yield info.initialize ();
        directory_info_map[info.match_obj.uri] = info;
      }
      
      xdg_indexed = true;
    }

    public signal void zeitgeist_search_complete (ResultSet? rs, uint query_id);
    
    private void zg_plugin_search_done (ResultSet? rs, uint query_id)
    {
      zeitgeist_search_complete (rs, query_id);
    }
    
    private Gee.Collection<string> extract_directories (ResultSet rs)
    {
      Gee.Set<string> directories = new Gee.HashSet<string> ();
      
      foreach (var match in rs)
      {
        unowned UriMatch uri_match = match.key as UriMatch;
        if (uri_match == null) continue;
        var f = File.new_for_uri (uri_match.uri);
        if (!f.is_native () || !f.has_parent (null)) continue;
        var parent = f.get_parent ();
        var parent_uri = parent.get_uri ();
        if (parent_uri in directories) continue;
        
        directories.add (parent_uri);
      }

      return directories;
    }
    
    private string? home_dir_uri = null;
    
    private string[] get_dir_parents (string dir_uri, bool include_self)
    {
      string[] dirs = {};
      var f = File.new_for_uri (dir_uri);
      if (include_self) dirs += f.get_uri ();

      while (f.has_parent (null))
      {
        f = f.get_parent ();
        string parent_uri = f.get_uri ();
        if (config.home_dir_children_only &&
            !parent_uri.has_prefix (home_dir_uri)) break;
        dirs += parent_uri;
      }

      return dirs;
    }
    
    private async void process_directories (Gee.Collection<string>? dirs)
    {
      if (home_dir_uri == null)
      {
        var home_dir = Environment.get_home_dir ();
        if (home_dir != null)
        {
          var home = File.new_for_path (home_dir);
          home_dir_uri = home.get_uri () + "/";
        }
        else
        {
          warning ("Home directory is not set!");
          home_dir_uri = "file:///home/";
        }
      }

      if (dirs == null) return;

      foreach (var dir in dirs)
      {
        if (dir in directory_info_map) continue;
        if (config.home_dir_children_only &&
            !dir.has_prefix (home_dir_uri)) continue;

        string[] directories = get_dir_parents (dir, true);
        foreach (unowned string dir_uri in directories)
        {
          if (dir_uri in directory_info_map) continue;

          var info = new DirectoryInfo (dir_uri);
          yield info.initialize ();
          directory_info_map[info.match_obj.uri] = info;
        }
      }
    }

    public async ResultSet? search (Query q) throws SearchError
    {
      if (!(QueryFlags.UNCATEGORIZED in q.query_type)) return null;
      
      Gee.Collection<string>? directories = null;
      uint query_id = q.query_id;
      // wait for our signal or cancellable
      ulong sig_id = this.zeitgeist_search_complete.connect ((rs, q_id) =>
      {
        if (q_id != query_id) return;
        // let's mine directories ZG is aware of
        directories = extract_directories (rs);
        search.callback ();
      });
      ulong canc_sig_id = CancellableFix.connect (q.cancellable, () =>
      {
        // who knows what thread this runs in
        SignalHandler.block (this, sig_id); // is this thread-safe?
        Idle.add (search.callback);
      });

      if (connected_to_zg &&
          (data_sink.get_plugin ("SynapseZeitgeistPlugin") as ItemProvider).enabled)
      {
        // wait for results from ZeitgeistPlugin
        yield;
      }

      SignalHandler.disconnect (this, sig_id);
      q.cancellable.disconnect (canc_sig_id);

      q.check_cancellable ();
      if (!xdg_indexed) yield index_xdg_directories ();

      // process results from the zeitgeist plugin
      yield process_directories (directories);

      q.check_cancellable ();

      var rs = new ResultSet ();
      foreach (var entry in directory_info_map.values)
      {
        if (entry.name_folded.has_prefix (q.query_string_folded))
        {
          int relevancy = entry.match_obj.uri.has_prefix (home_dir_uri) ?
            Match.Score.VERY_GOOD - Match.Score.URI_PENALTY :
            Match.Score.ABOVE_AVERAGE - Match.Score.URI_PENALTY;
          rs.add (entry.match_obj, relevancy);
        }
      }
      
      return rs;
    }
  }
}
