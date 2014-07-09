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
  public interface Activatable : Object
  {
    // this property will eventually go away
    public abstract bool enabled { get; set; default = true; }

    public abstract void activate ();
    public abstract void deactivate ();
  }

  public interface Configurable : Object
  {
    public abstract Gtk.Widget create_config_widget ();
  }

  public interface ItemProvider : Activatable
  {
    public abstract async ResultSet? search (Query query) throws SearchError;
    public virtual bool handles_query (Query query)
    {
      return true;
    }
    public virtual bool handles_empty_query ()
    {
      return false;
    }
  }

  public interface ActionProvider : Activatable
  {
    public abstract ResultSet? find_for_match (ref Query query, Match match);
    public virtual bool handles_unknown ()
    {
      return false;
    }
  }

  // don't move into a class, gir doesn't like it
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

  public class PluginRegistry : Object
  {
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
}

