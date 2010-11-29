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
  public class ResultSet : Object, Gee.Iterable <Gee.Map.Entry <Match, int>>
  {
    protected Gee.Map<Match, int> matches;
    protected Gee.Set<unowned string> uris;

    public ResultSet ()
    {
      Object ();
    }

    construct
    {
      matches = new Gee.HashMap<Match, int> ();
      // Match.uri is not owned, so we can optimize here
      uris = new Gee.HashSet<unowned string> ();
    }

    public Type element_type
    {
      get { return matches.element_type; }
    }

    public int size
    {
      get { return matches.size; }
    }

    public Gee.Set<Match> keys
    {
      owned get { return matches.keys; }
    }

    public Gee.Set<Gee.Map.Entry <Match, int>> entries
    {
      owned get { return matches.entries; }
    }

    public Gee.Iterator<Gee.Map.Entry <Match, int>?> iterator ()
    {
      return matches.iterator ();
    }

    public void add (Match match, int relevancy)
    {
      matches.set (match, relevancy);

      if (match is UriMatch)
      {
        unowned string uri = (match as UriMatch).uri;
        if (uri != null && uri != "")
        {
          uris.add (uri);
        }
      }
    }

    public void add_all (ResultSet? rs)
    {
      if (rs == null) return;
      matches.set_all (rs.matches);
      uris.add_all (rs.uris);
    }

    public bool contains_uri (string uri)
    {
      return uri in uris;
    }

    public Gee.List<Match> get_sorted_list ()
    {
      var l = new Gee.ArrayList<Gee.Map.Entry<Match, int>> ();
      l.add_all (matches.entries);

      l.sort ((a, b) => 
      {
        unowned Gee.Map.Entry<Match, int> e1 = (Gee.Map.Entry<Match, int>) a;
        unowned Gee.Map.Entry<Match, int> e2 = (Gee.Map.Entry<Match, int>) b;
        int relevancy_delta = e2.value - e1.value;
        if (relevancy_delta != 0) return relevancy_delta;
        // FIXME: utf8 compare!
        else return e1.key.title.ascii_casecmp (e2.key.title);
      });

      var sorted_list = new Gee.ArrayList<Match> ();
      foreach (Gee.Map.Entry<Match, int> m in l)
      {
        sorted_list.add (m.key);
      }

      return sorted_list;
    }
  }

  public errordomain SearchError
  {
    SEARCH_CANCELLED,
    UNKNOWN_ERROR
  }
  
  public abstract class DataPlugin : Object
  {
    public unowned DataSink data_sink { get; construct; }
    public bool enabled { get; set; default = true; }

    public abstract async ResultSet? search (Query query) throws SearchError;

    // weirdish kind of signal cause DataSink will be emitting it for the plugin
    public signal void search_done (ResultSet rs, uint query_id);
  }
  
  public abstract class ActionPlugin : DataPlugin
  {
    public abstract bool handles_unknown ();
    public abstract ResultSet? find_for_match (Query query, Match match);
    public virtual bool provides_data ()
    {
      return false;
    }
    public override async ResultSet? search (Query query) throws SearchError
    {
      assert_not_reached ();
    }
  }

  public class DataSink : Object
  {
    public class PluginRegistry : Object
    {
      public class PluginInfo
      {
        public Type plugin_type;
        public string title;
        public string description;
        public string icon_name;
        public bool runnable;
        public string runnable_error;
        public PluginInfo (Type type, string title, string desc,
                           string icon_name, bool runnable,
                           string runnable_error)
        {
          this.plugin_type = type;
          this.title = title;
          this.description = desc;
          this.icon_name = icon_name;
          this.runnable = runnable;
          this.runnable_error = runnable_error;
        }
      }

      public static unowned PluginRegistry instance = null;

      private Gee.List<PluginInfo> plugins;
      
      construct
      {
        instance = this;
        plugins = new Gee.ArrayList<PluginInfo> ();
      }
      
      ~PluginRegistry ()
      {
        instance = null;
      }
      
      public static PluginRegistry get_default ()
      {
        return instance ?? new PluginRegistry ();
      }
      
      public void register_plugin (Type plugin_type,
                                   string title,
                                   string description,
                                   string icon_name,
                                   bool runnable = true,
                                   string runnable_error = "")
      {
        var p = new PluginInfo (plugin_type, title, description, icon_name,
                                runnable, runnable_error);
        plugins.add (p);
      }
      
      public Gee.List<PluginInfo> get_plugins ()
      {
        return plugins.read_only_view;
      }
    }
    
    private class DataSinkConfiguration : ConfigObject
    {
      // vala keeps array lengths, and therefore doesn't support setting arrays
      // via automatic public properties
      private string[] _disabled_plugins = null;
      public string[] disabled_plugins
      {
        get
        {
          return _disabled_plugins;
        }
        set
        {
          _disabled_plugins = value;
        }
      }
      
      public void set_plugin_enabled (Type t, bool enabled)
      {
        if (enabled) enable_plugin (t.name ());
        else disable_plugin (t.name ());
      }
      
      public bool is_plugin_enabled (Type t)
      {
        if (_disabled_plugins == null) return true;
        unowned string plugin_name = t.name ();
        foreach (string s in _disabled_plugins)
        {
          if (s == plugin_name) return false;
        }
        return true;
      }
      
      private void enable_plugin (string name)
      {
        if (_disabled_plugins == null) return;
        if (!(name in _disabled_plugins)) return;
        
        string[] cpy = {};
        foreach (string s in _disabled_plugins)
        {
          if (s != name) cpy += s;
        }
        _disabled_plugins = (owned) cpy;
      }
      
      private void disable_plugin (string name)
      {
        if (_disabled_plugins == null || !(name in _disabled_plugins))
        {
          _disabled_plugins += name;
        }
      }
    }
    
    public DataSink ()
    {
    }

    ~DataSink ()
    {
      debug ("DataSink died...");
    }

    private DataSinkConfiguration config;
    private Gee.Set<DataPlugin> plugins;
    private Gee.Set<ActionPlugin> actions;
    private uint query_id;
    // data sink will keep reference to the name cache, so others will get this
    // instance on call to get_default()
    private DBusNameCache dbus_name_cache;
    private DesktopFileService desktop_file_service;
    private PluginRegistry registry;

    construct
    {
      plugins = new Gee.HashSet<DataPlugin> ();
      actions = new Gee.HashSet<ActionPlugin> ();
      query_id = 0;

      var cfg = Configuration.get_default ();
      config = (DataSinkConfiguration)
        cfg.get_config ("data-sink", "global", typeof (DataSinkConfiguration));

      // oh well, yea we need a few singletons
      registry = PluginRegistry.get_default ();
      
      initialize_caches ();
    }
    
    private async void initialize_caches ()
    {
      int initialized_components = 0;
      int NUM_COMPONENTS = 2;
      
      dbus_name_cache = DBusNameCache.get_default ();
      ulong sid1 = dbus_name_cache.initialization_done.connect (() =>
      {
        initialized_components++;
        if (initialized_components >= NUM_COMPONENTS)
        {
          initialize_caches.callback ();
        }
      });
      
      desktop_file_service = DesktopFileService.get_default ();
      ulong sid2 = desktop_file_service.initialization_done.connect (() =>
      {
        initialized_components++;
        if (initialized_components >= NUM_COMPONENTS)
        {
          initialize_caches.callback ();
        }
      });
      
      yield;
      SignalHandler.disconnect (dbus_name_cache, sid1);
      SignalHandler.disconnect (desktop_file_service, sid2);

      Idle.add (() => { this.load_plugins (); return false; });
    }

    private bool has_unknown_handlers = false;
    private bool plugins_loaded = false;

    protected void register_plugin (DataPlugin plugin)
    {
      if (plugin is ActionPlugin)
      {
        ActionPlugin? action_plugin = plugin as ActionPlugin;
        actions.add (action_plugin);
        has_unknown_handlers |= action_plugin.handles_unknown ();
        
        if (action_plugin.provides_data ()) plugins.add (action_plugin);
      }
      else
      {
        plugins.add (plugin);
      }
    }
    
    private void update_has_unknown_handlers ()
    {
      has_unknown_handlers = false;
      foreach (var action in actions)
      {
        if (action.enabled && action.handles_unknown ())
        {
          has_unknown_handlers = true;
          return;
        }
      }
    }
    
    private DataPlugin? create_plugin (Type t)
    {
      return Object.new (t, "data-sink", this, null) as DataPlugin;
    }

    private void load_plugins ()
    {
      // FIXME: turn into proper modules
      Type[] plugin_types =
      {
        typeof (DesktopFilePlugin),
        typeof (ZeitgeistPlugin),
        typeof (HybridSearchPlugin),
        typeof (GnomeSessionPlugin),
        typeof (UPowerPlugin),
        typeof (CommandPlugin),
        typeof (RhythmboxActions),
        typeof (DirectoryPlugin),
#if TEST_PLUGINS
        typeof (TestSlowPlugin),
#endif

        typeof (CommonActions),
        typeof (DictionaryPlugin),
        typeof (DevhelpPlugin)
      };

      foreach (Type t in plugin_types)
      {
        t.class_ref (); // makes the plugin register itself into PluginRegistry
        if (config.is_plugin_enabled (t))
          register_plugin (create_plugin (t));
      }
      
      plugins_loaded = true;
    }
    
    public unowned DataPlugin? get_plugin (string name)
    {
      unowned DataPlugin? result = null;
      
      foreach (var plugin in plugins)
      {
        if (plugin.get_type ().name () == name)
        {
          result = plugin;
          break;
        }
      }
      
      return result;
    }
    
    public bool is_plugin_enabled (Type plugin_type)
    {
      foreach (var plugin in plugins)
      {
        if (plugin.get_type () == plugin_type) return plugin.enabled;
      }
      
      foreach (var action in actions)
      {
        if (action.get_type () == plugin_type) return action.enabled;
      }
      
      return false;
    }
    
    public void set_plugin_enabled (Type plugin_type, bool enabled)
    {
      // save it into our config object
      config.set_plugin_enabled (plugin_type, enabled);
      Configuration.get_default ().set_config ("data-sink", "global", config);
      
      foreach (var plugin in plugins)
      {
        if (plugin.get_type () == plugin_type)
        {
          plugin.enabled = enabled;
          return;
        }
      }

      foreach (var action in actions)
      {
        if (action.get_type () == plugin_type)
        {
          action.enabled = enabled;
          update_has_unknown_handlers ();
          return;
        }
      }

      // plugin isn't instantiated yet
      if (enabled)
      {
        register_plugin (create_plugin (plugin_type));
      }
    }

    public async Gee.List<Match> search (string query,
                                         QueryFlags flags,
                                         ResultSet? dest_result_set,
                                         Cancellable? cancellable = null) throws SearchError
    {
      // wait for our initialization
      while (!plugins_loaded)
      {
        Timeout.add (50, search.callback);
        yield;
      }
      var q = Query (query_id++, query, flags);

      var cancellables = new GLib.List<Cancellable> ();

      var current_result_set = dest_result_set ?? new ResultSet ();
      int search_size = plugins.size;
      // FIXME: this is probably useless, if async method finishes immediately,
      // it'll call complete_in_idle
      bool waiting = false;

      foreach (var data_plugin in plugins)
      {
        if (!data_plugin.enabled)
        {
          search_size--;
          continue;
        }
        // we need to pass separate cancellable to each plugin, because we're
        // running them in parallel
        var c = new Cancellable ();
        cancellables.prepend (c);
        q.cancellable = c;
        // magic comes here
        data_plugin.search.begin (q, (src_obj, res) =>
        {
          var plugin = src_obj as DataPlugin;
          try
          {
            var results = plugin.search.end (res);
            plugin.search_done (results, q.query_id);
            current_result_set.add_all (results);
          }
          catch (SearchError err)
          {
            if (!(err is SearchError.SEARCH_CANCELLED))
            {
              warning ("%s returned error: %s",
                       plugin.get_type ().name (), err.message);
            }
          }

          if (--search_size == 0 && waiting) search.callback ();
        });
      }
      cancellables.reverse ();
      
      if (cancellable != null)
      {
        CancellableFix.connect (cancellable, () =>
        {
          foreach (var c in cancellables) c.cancel();
        });
      }

      waiting = true;
      if (search_size > 0) yield;

      if (cancellable != null && cancellable.is_cancelled ())
      {
        throw new SearchError.SEARCH_CANCELLED ("Cancelled");
      }
      
      if (has_unknown_handlers && 
        (QueryFlags.UNCATEGORIZED in flags || QueryFlags.ACTIONS in flags))
      {
        current_result_set.add (new DefaultMatch (query), 0);
      }

      return current_result_set.get_sorted_list ();
    }

    public Gee.List<Match> find_actions_for_match (Match match, string? query)
    {
      var rs = new ResultSet ();
      var q = Query (0, query ?? "");
      foreach (var action_plugin in actions)
      {
        if (!action_plugin.enabled) continue;
        rs.add_all (action_plugin.find_for_match (q, match));
      }
      
      return rs.get_sorted_list ();
    }
  }
}

