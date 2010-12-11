/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
{
  public errordomain SearchError
  {
    SEARCH_CANCELLED,
    UNKNOWN_ERROR
  }

  public class DataSink : Object
  {
    public class PluginRegistry : Object
    {
      [CCode (has_target = false)]
      public delegate void PluginRegisterFunc ();
  
      public class PluginInfo
      {
        public Type plugin_type;
        public string title;
        public string description;
        public string icon_name;
        public PluginRegisterFunc register_func;
        public bool runnable;
        public string runnable_error;
        public PluginInfo (Type type, string title, string desc,
                           string icon_name, PluginRegisterFunc reg_func,
                           bool runnable, string runnable_error)
        {
          this.plugin_type = type;
          this.title = title;
          this.description = desc;
          this.icon_name = icon_name;
          this.register_func = reg_func;
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
                                   PluginRegisterFunc reg_func,
                                   bool runnable = true,
                                   string runnable_error = "")
      {
        // FIXME: how about a frickin Type -> PluginInfo map?!
        int index = -1;
        for (int i=0; i < plugins.size; i++)
        {
          if (plugins[i].plugin_type == plugin_type)
          {
            index = i;
            break;
          }
        }
        if (index >= 0) plugins.remove_at (index);
        
        var p = new PluginInfo (plugin_type, title, description, icon_name,
                                reg_func, runnable, runnable_error);
        plugins.add (p);
      }
      
      public Gee.List<PluginInfo> get_plugins ()
      {
        return plugins.read_only_view;
      }
      
      public PluginInfo? get_plugin_info_for_type (Type plugin_type)
      {
        foreach (PluginInfo pi in plugins)
        {
          if (pi.plugin_type == plugin_type) return pi;
        }
        
        return null;
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
    private RelevancyService relevancy_service;
    private Type[] plugin_types;

    construct
    {
      plugins = new Gee.HashSet<DataPlugin> ();
      actions = new Gee.HashSet<ActionPlugin> ();
      plugin_types = {};
      query_id = 0;

      var cfg = ConfigService.get_default ();
      config = (DataSinkConfiguration)
        cfg.get_config ("data-sink", "global", typeof (DataSinkConfiguration));

      // oh well, yea we need a few singletons
      registry = PluginRegistry.get_default ();
      relevancy_service = RelevancyService.get_default ();

      initialize_caches ();
      register_static_plugin (typeof (CommonActions));
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
      desktop_file_service.reload_done.connect (this.check_plugins);
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
    
    private void check_plugins ()
    {
      PluginRegistry.PluginRegisterFunc[] reg_funcs = {};
      foreach (var pi in registry.get_plugins ())
      {
        reg_funcs += pi.register_func;
      }

      foreach (PluginRegistry.PluginRegisterFunc func in reg_funcs)
      {
        func ();
      }
    }

    private bool has_unknown_handlers = false;
    private bool plugins_loaded = false;

    public signal void plugin_registered (DataPlugin plugin);

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
      
      plugin_registered (plugin);
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
      // FIXME: fetch and load modules
      foreach (Type t in plugin_types)
      {
        t.class_ref (); // makes the plugin register itself into PluginRegistry
        PluginRegistry.PluginInfo? info = registry.get_plugin_info_for_type (t);
        bool skip = info != null && info.runnable == false;
        if (config.is_plugin_enabled (t) && !skip)
          register_plugin (create_plugin (t));
      }

      plugins_loaded = true;
    }
    
    /* This needs to be called right after instantiation,
     * if plugins_loaded == true, it won't have any effect. */
    public void register_static_plugin (Type plugin_type)
    {
      if (plugin_type in plugin_types) return;
      plugin_types += plugin_type;
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
      ConfigService.get_default ().set_config ("data-sink", "global", config);
      
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
        Timeout.add (100, search.callback);
        yield;
        if (cancellable != null && cancellable.is_cancelled ())
        {
          throw new SearchError.SEARCH_CANCELLED ("Cancelled");
        }
      }
      var q = Query (query_id++, query, flags);
      string query_stripped = query.strip ();

      var cancellables = new GLib.List<Cancellable> ();

      var current_result_set = dest_result_set ?? new ResultSet ();
      int search_size = plugins.size;
      // FIXME: this is probably useless, if async method finishes immediately,
      // it'll call complete_in_idle
      bool waiting = false;

      foreach (var data_plugin in plugins)
      {
        bool skip = !data_plugin.enabled ||
          (query == "" && !data_plugin.handles_empty_query ());
        if (skip)
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
          foreach (var c in cancellables) c.cancel ();
        });
      }

      waiting = true;
      if (search_size > 0) yield;

      if (cancellable != null && cancellable.is_cancelled ())
      {
        throw new SearchError.SEARCH_CANCELLED ("Cancelled");
      }
      
      if (has_unknown_handlers && query_stripped != "" &&
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

